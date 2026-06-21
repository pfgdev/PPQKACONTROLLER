local mq = require('mq')
require('ImGui')

local SCRIPT_NAME = 'PPQKissAssistManager'
local CONFIG_MODULE = 'ppqka.config.ppq_g1'

local terminate = false
local isOpen = true
local shouldDraw = true
local showDebug = false
local dryRunLog = {}
local lastRefresh = 0
local lastStatusQuery = 0
local STATUS_QUERY_SECONDS = 8
local STATUS_QUERIES = {
  'Macro.Name',
  'Macro.Paused',
}
local discovery = {
  local_name = 'unknown',
  version = 'unknown',
  peer_count = 0,
  peers = {},
  joined = {},
  groups = {},
}
local statusCache = {}

local ok, configOrError = pcall(require, CONFIG_MODULE)
local config = ok and configOrError or {
  name = 'Config failed to load',
  assist = '',
  groups = {},
  display_groups = {},
  active_profiles = {},
  characters = {},
  command_templates = {},
  command_sequences = {},
}

if not ok then
  print(string.format('[%s] Failed to load %s: %s', SCRIPT_NAME, CONFIG_MODULE, tostring(configOrError)))
end

local function safeTlo(label, getter, fallback)
  local success, value = pcall(getter)
  if success and value ~= nil then
    return value
  end

  return fallback
end

local function splitPipeList(value)
  local items = {}
  local text = tostring(value or '')

  for item in text:gmatch('[^|]+') do
    if item ~= '' then
      table.insert(items, item)
    end
  end

  table.sort(items)
  return items
end

local function sortedGroupEntries(groups)
  local entries = {}

  for key, groupName in pairs(groups or {}) do
    table.insert(entries, {
      key = key,
      name = groupName,
    })
  end

  table.sort(entries, function(left, right)
    return left.key < right.key
  end)

  return entries
end

local function displayGroups()
  if config.display_groups and #config.display_groups > 0 then
    return config.display_groups
  end

  local groups = config.groups or {}
  return {
    {
      label = 'Group 1',
      peers = groups.all or 'g1',
      control = groups.kiss or 'g1kiss',
    },
    {
      label = 'Group 2',
      peers = groups.group2 or 'g2',
      control = groups.group2kiss or 'g2kiss',
    },
  }
end

local function peersForGroup(groupName)
  for _, group in pairs(discovery.groups or {}) do
    if group.name == groupName then
      return group.peers or {}
    end
  end

  return splitPipeList(safeTlo('DanNet.Peers[' .. tostring(groupName) .. ']', function()
    return mq.TLO.DanNet.Peers(groupName)()
  end, ''))
end

local function allDisplayPeers()
  local seen = {}
  local peers = {}

  for _, group in ipairs(displayGroups()) do
    for _, peer in ipairs(peersForGroup(group.peers)) do
      if not seen[peer] then
        seen[peer] = true
        table.insert(peers, peer)
      end
    end
  end

  table.sort(peers)
  return peers
end

local function refreshDanNetDiscovery()
  discovery.local_name = safeTlo('DanNet.Name', function()
    return mq.TLO.DanNet.Name()
  end, 'unavailable')

  discovery.version = safeTlo('DanNet.Version', function()
    return mq.TLO.DanNet.Version()
  end, 'unavailable')

  discovery.peer_count = safeTlo('DanNet.PeerCount', function()
    return mq.TLO.DanNet.PeerCount()
  end, 0)

  discovery.peers = splitPipeList(safeTlo('DanNet.Peers', function()
    return mq.TLO.DanNet.Peers()
  end, ''))

  discovery.joined = splitPipeList(safeTlo('DanNet.Joined', function()
    return mq.TLO.DanNet.Joined()
  end, ''))

  discovery.groups = {}

  for _, group in ipairs(sortedGroupEntries(config.groups)) do
    discovery.groups[group.key] = {
      name = group.name,
      peers = splitPipeList(safeTlo('DanNet.Peers[' .. group.name .. ']', function()
        return mq.TLO.DanNet.Peers(group.name)()
      end, '')),
    }
  end
end

local function formatList(items)
  if not items or #items == 0 then
    return '(none)'
  end

  return table.concat(items, ', ')
end

local function savedProfileFor(characterName)
  local characterKey = string.lower(characterName or '')
  local activeProfiles = config.active_profiles or {}
  local profileKey = activeProfiles[characterName] or activeProfiles[characterKey]

  if not profileKey then
    return 'unknown'
  end

  local profiles = config.profiles or {}
  local characterProfiles = profiles[characterName] or profiles[characterKey] or {}
  local profile = characterProfiles[profileKey]

  if type(profile) == 'table' then
    local label = profile.label or profileKey
    local ini = profile.ini or 'unknown'
    return string.format('%s (%s)', label, ini)
  end

  if type(profile) == 'string' then
    return string.format('%s (%s)', profileKey, profile)
  end

  return tostring(profileKey)
end

local function normalizePeerName(name)
  return string.lower(tostring(name or ''))
end

local function isLocalPeer(characterName)
  return normalizePeerName(characterName) == normalizePeerName(discovery.local_name)
end

local function readLocalMacroStatus()
  return {
    macro_name = safeTlo('Macro.Name', function()
      return mq.TLO.Macro.Name()
    end, ''),
    macro_paused = safeTlo('Macro.Paused', function()
      return mq.TLO.Macro.Paused()
    end, false),
    query_ok = true,
  }
end

local function readPeerQuery(peer, query)
  return safeTlo('DanNet[' .. tostring(peer) .. '].Q[' .. query .. ']', function()
    return mq.TLO.DanNet(peer).Q(query)()
  end, nil)
end

local function submitPeerStatusQueries(peer)
  if isLocalPeer(peer) then
    local cached = statusCache[peer] or {}
    local localStatus = readLocalMacroStatus()
    cached.macro_name = localStatus.macro_name
    cached.macro_paused = localStatus.macro_paused
    cached.query_ok = localStatus.query_ok
    statusCache[peer] = cached
    return
  end

  statusCache[peer] = statusCache[peer] or {}

  for _, query in ipairs(STATUS_QUERIES) do
    local success, errorMessage = pcall(function()
      mq.cmdf('/dquery %s -q %s -t 1000', peer, query)
    end)

    if not success then
      statusCache[peer].query_error = tostring(errorMessage)
    end
  end
end

local function refreshPeerStatusQueries()
  for _, peer in ipairs(allDisplayPeers()) do
    submitPeerStatusQueries(peer)
  end
end

local function updatePeerStatusFromQueries(peer)
  if isLocalPeer(peer) then
    local cached = statusCache[peer] or {}
    local localStatus = readLocalMacroStatus()
    cached.macro_name = localStatus.macro_name
    cached.macro_paused = localStatus.macro_paused
    cached.query_ok = localStatus.query_ok
    statusCache[peer] = cached
    return cached
  end

  local status = statusCache[peer] or {}
  local macroName = readPeerQuery(peer, 'Macro.Name')
  local macroPaused = readPeerQuery(peer, 'Macro.Paused')

  if macroName ~= nil then
    status.macro_name = tostring(macroName)
  end

  if macroPaused ~= nil then
    status.macro_paused = tostring(macroPaused)
  end

  status.query_ok = status.macro_name ~= nil or status.macro_paused ~= nil
  statusCache[peer] = status
  return status
end

local function statusFor(characterName)
  local status = updatePeerStatusFromQueries(characterName)
  local macroName = tostring(status.macro_name or '')
  local normalizedMacroName = string.lower(macroName)

  if normalizedMacroName == '' or normalizedMacroName == 'null' then
    return 'inactive'
  end

  if string.find(normalizedMacroName, 'kiss') then
    return 'active'
  end

  if status.query_ok then
    return 'inactive'
  end

  return 'unknown'
end

local function firstProfile(character)
  if character.default_profile and character.default_profile ~= '' then
    return character.default_profile
  end

  if character.profiles and character.profiles[1] then
    return character.profiles[1].ini
  end

  return ''
end

local function expandTemplate(template, values)
  local expanded = template or ''

  for key, value in pairs(values) do
    expanded = expanded:gsub('{' .. key .. '}', tostring(value or ''))
  end

  return expanded
end

local function commandForCharacter(character, templateName)
  local templates = config.command_templates or {}
  return expandTemplate(templates[templateName], {
    assist = config.assist,
    character = character.name,
    profile = firstProfile(character),
  })
end

local function commandForGroup(groupName, templateName)
  local templates = config.command_templates or {}
  return expandTemplate(templates[templateName], {
    assist = config.assist,
    group = groupName,
  })
end

local function logDryRun(label, commandText)
  local line = string.format('[%s] DRY-RUN %s: %s', SCRIPT_NAME, label, commandText)
  table.insert(dryRunLog, 1, line)

  if #dryRunLog > 8 then
    table.remove(dryRunLog)
  end

  print(line)
end

local function drawStatusHeader()
  ImGui.Text('Character')
  ImGui.SameLine(150)
  ImGui.Text('Status')
  ImGui.SameLine(260)
  ImGui.Text('Active profile')
end

local function drawStatusRow(characterName)
  ImGui.Text(characterName)
  ImGui.SameLine(150)
  ImGui.Text(statusFor(characterName))
  ImGui.SameLine(260)
  ImGui.Text(savedProfileFor(characterName))
end

local function drawStatusOverview()
  ImGui.Text(config.name or 'PPQ KissAssist Manager')
  ImGui.Text('Status overview')
  ImGui.Separator()

  for _, group in ipairs(displayGroups()) do
    local peers = peersForGroup(group.peers)

    ImGui.Text(group.label or group.peers or 'Group')
    ImGui.SameLine(150)
    ImGui.Text('Peers: ' .. tostring(#peers))
    if group.control then
      ImGui.SameLine(260)
      ImGui.Text('Control: ' .. group.control)
    end

    drawStatusHeader()

    if #peers == 0 then
      ImGui.Text('(no peers reported)')
    else
      for _, peer in ipairs(peers) do
        drawStatusRow(peer)
      end
    end

    ImGui.Separator()
  end
end

local function drawCharacterRow(character)
  local characterName = character.name or 'unknown'

  ImGui.Separator()
  ImGui.Text(characterName)
  ImGui.SameLine(130)
  ImGui.Text(character.class or '')
  ImGui.SameLine(220)
  ImGui.Text(character.role or '')

  local profile = firstProfile(character)
  if profile ~= '' then
    ImGui.Text('Default profile: ' .. profile)
  else
    ImGui.Text('Default profile: none')
  end

  if character.kiss_enabled then
    if ImGui.Button('Dry Start Default##start_' .. characterName) then
      logDryRun(characterName .. ' start default', commandForCharacter(character, 'character_start_default'))
    end
  else
    ImGui.Text('Manual character: start button hidden for now.')
  end

  if character.kiss_enabled and profile ~= '' then
    ImGui.SameLine()

    if ImGui.Button('Dry Start Profile##start_profile_' .. characterName) then
      logDryRun(characterName .. ' start profile', commandForCharacter(character, 'character_start_profile'))
    end
  end

  if character.kiss_enabled then
    ImGui.SameLine()
  end

  if ImGui.Button('Dry Pause##pause_' .. characterName) then
    logDryRun(characterName .. ' pause', commandForCharacter(character, 'character_pause'))
  end

  ImGui.SameLine()

  if ImGui.Button('Dry Resume##resume_' .. characterName) then
    logDryRun(characterName .. ' resume', commandForCharacter(character, 'character_resume'))
  end

  ImGui.SameLine()

  if ImGui.Button('Dry End##end_' .. characterName) then
    logDryRun(characterName .. ' end', commandForCharacter(character, 'character_end'))
  end
end

local function drawGroupActions()
  local groups = config.groups or {}
  local kissGroup = groups.kiss or 'g1kiss'
  local allGroup = groups.all or 'g1'

  ImGui.Text('Group dry-run actions')

  if ImGui.Button('Dry Start Kiss Group') then
    logDryRun('group start', commandForGroup(kissGroup, 'group_start'))
  end

  ImGui.SameLine()

  if ImGui.Button('Dry Pause Kiss Group') then
    logDryRun('group pause', commandForGroup(kissGroup, 'group_pause'))
  end

  ImGui.SameLine()

  if ImGui.Button('Dry Resume Kiss Group') then
    logDryRun('group resume', commandForGroup(kissGroup, 'group_resume'))
  end

  ImGui.SameLine()

  if ImGui.Button('Dry End Kiss Group') then
    logDryRun('group end', commandForGroup(kissGroup, 'group_end'))
  end

  if ImGui.Button('Dry Hard Stop All') then
    local commands = {}
    local sequences = config.command_sequences or {}
    for _, template in ipairs(sequences.group_hard_stop or {}) do
      table.insert(commands, expandTemplate(template, { group = allGroup }))
    end
    logDryRun('group hard stop', table.concat(commands, ' ; '))
  end
end

local function drawDanNetDiscovery()
  ImGui.Text('DanNet discovery')
  ImGui.Text('Local: ' .. tostring(discovery.local_name))
  ImGui.Text('Version: ' .. tostring(discovery.version))
  ImGui.Text('Peer count: ' .. tostring(discovery.peer_count))
  ImGui.TextWrapped('All peers: ' .. formatList(discovery.peers))
  ImGui.TextWrapped('Joined groups: ' .. formatList(discovery.joined))

  if ImGui.Button('Refresh DanNet') then
    refreshDanNetDiscovery()
    logDryRun('refresh', 'Read local DanNet peer/group TLOs')
  end

  ImGui.Separator()
  ImGui.Text('Configured DanNet groups')

  for _, group in ipairs(sortedGroupEntries(config.groups)) do
    local groupDiscovery = discovery.groups[group.key] or { peers = {} }
    ImGui.Text(group.key .. ': ' .. group.name)
    ImGui.SameLine(180)
    ImGui.TextWrapped(formatList(groupDiscovery.peers))
  end

  ImGui.Separator()
  ImGui.Text('Status query debug')

  for _, peer in ipairs(allDisplayPeers()) do
    local status = updatePeerStatusFromQueries(peer)
    ImGui.Text(peer)
    ImGui.SameLine(150)
    ImGui.Text('Macro.Name: ' .. tostring(status.macro_name or 'unknown'))
    ImGui.SameLine(360)
    ImGui.Text('Paused: ' .. tostring(status.macro_paused or 'unknown'))

    if status.query_error then
      ImGui.TextWrapped('Query error: ' .. status.query_error)
    end
  end
end

local function render()
  if not isOpen then
    return
  end

  isOpen, shouldDraw = ImGui.Begin('PPQ KissAssist Manager', isOpen)

  if shouldDraw then
    drawStatusOverview()

    if ImGui.Button('Refresh') then
      refreshDanNetDiscovery()
      refreshPeerStatusQueries()
      logDryRun('refresh', 'Read local DanNet peer/group TLOs and query macro status')
    end

    ImGui.SameLine()

    if ImGui.Button(showDebug and 'Hide debug' or 'Show debug') then
      showDebug = not showDebug
    end

    ImGui.Text('Read-only status scaffold. Macro status uses DanNet queries; profiles are still local/unknown.')
    ImGui.Separator()

    if showDebug then
      drawDanNetDiscovery()

      ImGui.Separator()

      drawGroupActions()

      ImGui.Separator()
      ImGui.Text('Configured characters')

      local characters = config.characters or {}
      if #characters == 0 then
        ImGui.Text('No configured character rows. Top table is built from DanNet groups.')
      else
        for _, character in ipairs(characters) do
          drawCharacterRow(character)
        end
      end

      ImGui.Separator()
      ImGui.Text('Dry-run log')

      if #dryRunLog == 0 then
        ImGui.Text('No dry-run actions yet.')
      else
        for _, line in ipairs(dryRunLog) do
          ImGui.TextWrapped(line)
        end
      end

      ImGui.Separator()
    end

    if ImGui.Button('Close Script') then
      terminate = true
    end
  end

  ImGui.End()
end

mq.imgui.init(SCRIPT_NAME, render)
refreshDanNetDiscovery()
refreshPeerStatusQueries()
lastStatusQuery = os.time()

while not terminate do
  local now = os.time()
  if now - lastRefresh >= 5 then
    refreshDanNetDiscovery()
    lastRefresh = now
  end

  if now - lastStatusQuery >= STATUS_QUERY_SECONDS then
    refreshPeerStatusQueries()
    lastStatusQuery = now
  end

  mq.delay(500)
end

mq.imgui.destroy(SCRIPT_NAME)
