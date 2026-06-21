local mq = require('mq')
require('ImGui')

local SCRIPT_NAME = 'PPQKissAssistManager'
local CONFIG_MODULE = 'ppqka.config.ppq_g1'

local terminate = false
local isOpen = true
local shouldDraw = true
local showDebug = false
local selectedLoadoutKey = nil
local dryRunLog = {}
local commandQueue = {}
local lastRefresh = 0
local lastStatusQuery = 0
local STATUS_QUERY_SECONDS = 8
local STATUS_QUERIES = {
  'Macro.Name',
}
local PAUSED_PROBE_READ_DELAY_SECONDS = 2
local DEFAULT_END_TO_START_DELAY_MS = 2000
local DEFAULT_LOADOUT_END_SPACING_MS = 250
local DEFAULT_LOADOUT_START_SPACING_MS = 750
local discovery = {
  local_name = 'unknown',
  version = 'unknown',
  peer_count = 0,
  peers = {},
  joined = {},
  groups = {},
}
local statusCache = {}
local pausedProbe = {
  quiet_until = 0,
  results = {},
}

local ok, configOrError = pcall(require, CONFIG_MODULE)
local config = ok and configOrError or {
  name = 'Config failed to load',
  assist = '',
  groups = {},
  display_groups = {},
  active_profiles = {},
  loadouts = {},
  command_timing = {},
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

local function timingValue(key, fallback)
  local timing = config.command_timing or {}
  return tonumber(timing[key]) or fallback
end

local function characterConfigKey(characterName)
  return string.lower(characterName or '')
end

local function profileEntriesFor(characterName)
  local characterKey = string.lower(characterName or '')
  local profiles = config.profiles or {}
  local characterProfiles = profiles[characterName] or profiles[characterKey] or {}
  local entries = {}

  for key, profile in pairs(characterProfiles) do
    local label = key
    local ini = ''

    if type(profile) == 'table' then
      label = profile.label or key
      ini = profile.ini or ''
    elseif type(profile) == 'string' then
      ini = profile
    end

    table.insert(entries, {
      key = key,
      label = label,
      ini = ini,
    })
  end

  table.sort(entries, function(left, right)
    return left.label < right.label
  end)

  return entries
end

local function selectedProfileKeyFor(characterName)
  local characterKey = characterConfigKey(characterName)
  local activeProfiles = config.active_profiles or {}
  return activeProfiles[characterName] or activeProfiles[characterKey]
end

local function profileForKey(characterName, profileKey)
  if not profileKey then
    return {
      key = nil,
      label = 'unknown',
      ini = 'unknown',
    }
  end

  local profiles = config.profiles or {}
  local characterProfiles = profiles[characterName] or profiles[characterConfigKey(characterName)] or {}
  local profile = characterProfiles[profileKey]

  if type(profile) == 'table' then
    return {
      key = profileKey,
      label = profile.label or profileKey,
      ini = profile.ini or 'unknown',
    }
  end

  if type(profile) == 'string' then
    return {
      key = profileKey,
      label = profileKey,
      ini = profile,
    }
  end

  return {
    key = profileKey,
    label = tostring(profileKey),
    ini = 'unknown',
  }
end

local function selectedProfileFor(characterName)
  return profileForKey(characterName, selectedProfileKeyFor(characterName))
end

local function loadoutEntries()
  local entries = {}

  for _, loadout in ipairs(config.loadouts or {}) do
    table.insert(entries, loadout)
  end

  table.sort(entries, function(left, right)
    return (left.label or left.key or '') < (right.label or right.key or '')
  end)

  return entries
end

local function selectedLoadout()
  local entries = loadoutEntries()

  if not selectedLoadoutKey and entries[1] then
    selectedLoadoutKey = entries[1].key
  end

  for _, loadout in ipairs(entries) do
    if loadout.key == selectedLoadoutKey then
      return loadout
    end
  end

  return entries[1]
end

local function loadoutProfileKeyFor(loadout, characterName)
  if not loadout or not loadout.characters then
    return nil
  end

  return loadout.characters[characterName] or loadout.characters[characterConfigKey(characterName)]
end

local function loadoutCharacterEntries(loadout)
  local entries = {}

  for characterName, profileKey in pairs((loadout and loadout.characters) or {}) do
    table.insert(entries, {
      character = characterName,
      profile = profileKey,
    })
  end

  table.sort(entries, function(left, right)
    return left.character < right.character
  end)

  return entries
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
    cached.query_ok = localStatus.query_ok
    statusCache[peer] = cached
    return cached
  end

  local status = statusCache[peer] or {}
  local macroName = readPeerQuery(peer, 'Macro.Name')

  if macroName ~= nil then
    status.macro_name = tostring(macroName)
  end

  status.query_ok = status.macro_name ~= nil
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

local function logAction(label, commandText)
  local line = string.format('[%s] %s: %s', SCRIPT_NAME, label, commandText)
  table.insert(dryRunLog, 1, line)

  if #dryRunLog > 8 then
    table.remove(dryRunLog)
  end

  print(line)
end

local function formatTimestamp(timestamp)
  if not timestamp then
    return 'never'
  end

  return os.date('%H:%M:%S', timestamp)
end

local function submitPausedProbe()
  local now = os.time()
  pausedProbe.quiet_until = now + PAUSED_PROBE_READ_DELAY_SECONDS + 2

  for _, peer in ipairs(allDisplayPeers()) do
    pausedProbe.results[peer] = pausedProbe.results[peer] or {}
    pausedProbe.results[peer].requested_at = now
    pausedProbe.results[peer].read_at = nil
    pausedProbe.results[peer].read_after = now + PAUSED_PROBE_READ_DELAY_SECONDS
    pausedProbe.results[peer].value = 'pending'
    pausedProbe.results[peer].error = nil

    if isLocalPeer(peer) then
      pausedProbe.results[peer].value = tostring(safeTlo('Macro.Paused', function()
        return mq.TLO.Macro.Paused()
      end, 'unknown'))
      pausedProbe.results[peer].read_at = now
      pausedProbe.results[peer].read_after = nil
    else
      local success, errorMessage = pcall(function()
        mq.cmdf('/dquery %s -q Macro.Paused -t 1000', peer)
      end)

      if not success then
        pausedProbe.results[peer].value = 'error'
        pausedProbe.results[peer].error = tostring(errorMessage)
        pausedProbe.results[peer].read_at = now
        pausedProbe.results[peer].read_after = nil
      end
    end
  end

  logAction('PROBE', 'Submitted isolated Macro.Paused queries')
end

local function updatePausedProbeReads()
  local now = os.time()

  for peer, result in pairs(pausedProbe.results) do
    if result.read_after and now >= result.read_after then
      local value = readPeerQuery(peer, 'Macro.Paused')
      result.value = value == nil and 'nil' or tostring(value)
      result.read_at = now
      result.read_after = nil
    end
  end
end

local function enqueueCommand(commandText, delayMs, target)
  table.insert(commandQueue, {
    due = mq.gettime() + (delayMs or 0),
    command = commandText,
    target = target,
  })
end

local function processCommandQueue()
  local now = mq.gettime()
  local index = 1

  while index <= #commandQueue do
    local queued = commandQueue[index]

    if queued.due <= now then
      mq.cmd(queued.command)
      logAction('COMMAND', queued.command)
      table.remove(commandQueue, index)
    else
      index = index + 1
    end
  end
end

local function clearQueuedCommandsForTargets(targets)
  local index = 1

  while index <= #commandQueue do
    local queued = commandQueue[index]

    if queued.target and targets[characterConfigKey(queued.target)] then
      table.remove(commandQueue, index)
    else
      index = index + 1
    end
  end
end

local function clearQueuedCommandsForCharacter(characterName)
  clearQueuedCommandsForTargets({
    [characterConfigKey(characterName)] = true,
  })
end

local function runSelectedProfile(characterName, profile)
  if not profile or not profile.ini or profile.ini == '' or profile.ini == 'unknown' then
    logAction('SKIP', 'No configured INI for ' .. tostring(characterName))
    return
  end

  local endCommand = string.format('/dex %s /end', characterName)
  local startCommand = string.format('/dex %s /mac kissassist ini %s assist ma %s', characterName, profile.ini, config.assist or '')

  clearQueuedCommandsForCharacter(characterName)
  enqueueCommand(endCommand, 0, characterName)
  enqueueCommand(startCommand, timingValue('end_to_start_delay_ms', DEFAULT_END_TO_START_DELAY_MS), characterName)
end

local function loadCharacterProfile(characterName, profile, assist, endDelayMs, startDelayMs)
  if not profile or not profile.ini or profile.ini == '' or profile.ini == 'unknown' then
    logAction('SKIP', 'No configured INI for ' .. tostring(characterName))
    return
  end

  enqueueCommand(string.format('/dex %s /end', characterName), endDelayMs, characterName)
  enqueueCommand(string.format('/dex %s /mac kissassist ini %s assist ma %s', characterName, profile.ini, assist or config.assist or ''), startDelayMs, characterName)
end

local function runLoadout(loadout)
  if not loadout then
    logAction('SKIP', 'No loadout selected')
    return
  end

  local assist = loadout.assist or config.assist
  local targets = {}
  local entries = loadoutCharacterEntries(loadout)

  for _, entry in ipairs(entries) do
    targets[characterConfigKey(entry.character)] = true
  end

  clearQueuedCommandsForTargets(targets)

  for index, entry in ipairs(entries) do
    config.active_profiles[characterConfigKey(entry.character)] = entry.profile
    local endSpacingMs = timingValue('loadout_end_spacing_ms', DEFAULT_LOADOUT_END_SPACING_MS)
    local startSpacingMs = timingValue('loadout_start_spacing_ms', DEFAULT_LOADOUT_START_SPACING_MS)
    local restartDelayMs = timingValue('end_to_start_delay_ms', DEFAULT_END_TO_START_DELAY_MS)

    loadCharacterProfile(
      entry.character,
      profileForKey(entry.character, entry.profile),
      assist,
      (index - 1) * endSpacingMs,
      restartDelayMs + ((index - 1) * startSpacingMs)
    )
  end
end

local function unloadLoadout(loadout)
  if not loadout then
    logAction('SKIP', 'No loadout selected')
    return
  end

  local targets = {}
  local entries = loadoutCharacterEntries(loadout)

  for _, entry in ipairs(entries) do
    targets[characterConfigKey(entry.character)] = true
  end

  clearQueuedCommandsForTargets(targets)

  for index, entry in ipairs(entries) do
    enqueueCommand(
      string.format('/dex %s /end', entry.character),
      (index - 1) * timingValue('loadout_end_spacing_ms', DEFAULT_LOADOUT_END_SPACING_MS),
      entry.character
    )
  end
end

local function loadoutIntentFor(characterName)
  local loadout = selectedLoadout()
  local profileKey = loadoutProfileKeyFor(loadout, characterName)

  if not profileKey then
    return 'not included'
  end

  local profile = profileForKey(characterName, profileKey)
  local activeKey = selectedProfileKeyFor(characterName)

  if activeKey == profileKey then
    return 'load ' .. profile.label
  end

  return 'change to ' .. profile.label
end

local function drawLoadoutControls()
  local entries = loadoutEntries()
  local loadout = selectedLoadout()

  ImGui.Text('Loadout')
  ImGui.SameLine(80)

  if #entries == 0 then
    ImGui.Text('none configured')
    return
  end

  ImGui.SetNextItemWidth(180)

  if ImGui.BeginCombo('##loadout_selector', loadout.label or loadout.key or 'unknown') then
    for _, entry in ipairs(entries) do
      local isSelected = entry.key == (loadout and loadout.key)

      if ImGui.Selectable(entry.label or entry.key, isSelected) then
        selectedLoadoutKey = entry.key
      end

      if isSelected then
        ImGui.SetItemDefaultFocus()
      end
    end

    ImGui.EndCombo()
  end

  ImGui.SameLine()

  if ImGui.Button('Load') then
    runLoadout(selectedLoadout())
  end

  ImGui.SameLine()

  if ImGui.Button('Unload') then
    unloadLoadout(selectedLoadout())
  end
end

local function drawStatusHeader()
  ImGui.Text('Character')
  ImGui.SameLine(150)
  ImGui.Text('Status')
  ImGui.SameLine(260)
  ImGui.Text('Active profile')
  ImGui.SameLine(380)
  ImGui.Text('Config file')
  ImGui.SameLine(620)
  ImGui.Text('Loadout')
end

local function drawProfileDropdown(characterName)
  local entries = profileEntriesFor(characterName)
  local selectedKey = selectedProfileKeyFor(characterName)
  local selectedProfile = selectedProfileFor(characterName)

  if #entries == 0 then
    ImGui.Text('unknown')
    return selectedProfile
  end

  ImGui.SetNextItemWidth(100)

  if ImGui.BeginCombo('##profile_' .. characterName, selectedProfile.label) then
    for _, entry in ipairs(entries) do
      local isSelected = entry.key == selectedKey

      if ImGui.Selectable(entry.label, isSelected) and entry.key ~= selectedKey then
        config.active_profiles[characterConfigKey(characterName)] = entry.key
        selectedProfile = selectedProfileFor(characterName)
        runSelectedProfile(characterName, selectedProfile)
      end

      if isSelected then
        ImGui.SetItemDefaultFocus()
      end
    end

    ImGui.EndCombo()
  end

  if ImGui.IsItemHovered() then
    ImGui.SetTooltip(selectedProfile.ini)
  end

  return selectedProfile
end

local function drawStatusRow(characterName)
  ImGui.Text(characterName)
  ImGui.SameLine(150)
  ImGui.Text(statusFor(characterName))
  ImGui.SameLine(260)
  local selectedProfile = drawProfileDropdown(characterName)
  ImGui.SameLine(380)
  ImGui.Text(selectedProfile.ini)
  ImGui.SameLine(620)
  ImGui.Text(loadoutIntentFor(characterName))
end

local function drawStatusOverview()
  ImGui.Text(config.name or 'PPQ KissAssist Manager')
  drawLoadoutControls()
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

  if ImGui.Button('Probe Macro.Paused only') then
    submitPausedProbe()
  end

  ImGui.Text('Normal polling query: Macro.Name')

  for _, peer in ipairs(allDisplayPeers()) do
    local status = updatePeerStatusFromQueries(peer)
    local probe = pausedProbe.results[peer] or {}

    ImGui.Text(peer)
    ImGui.SameLine(150)
    ImGui.Text('Macro.Name: ' .. tostring(status.macro_name or 'unknown'))
    ImGui.SameLine(360)
    ImGui.Text('Paused probe: ' .. tostring(probe.value or 'not run'))
    ImGui.SameLine(560)
    ImGui.Text('Read: ' .. formatTimestamp(probe.read_at))

    if probe.error then
      ImGui.TextWrapped('Paused probe error: ' .. probe.error)
    elseif status.query_error then
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

    ImGui.Text('Status uses DanNet queries. Changing a profile restarts KissAssist on that character.')
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
  processCommandQueue()
  updatePausedProbeReads()

  local now = os.time()
  if now - lastRefresh >= 5 then
    refreshDanNetDiscovery()
    lastRefresh = now
  end

  if now - lastStatusQuery >= STATUS_QUERY_SECONDS and now >= pausedProbe.quiet_until then
    refreshPeerStatusQueries()
    lastStatusQuery = now
  end

  mq.delay(500)
end

mq.imgui.destroy(SCRIPT_NAME)
