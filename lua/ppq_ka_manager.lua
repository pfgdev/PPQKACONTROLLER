local mq = require('mq')
require('ImGui')

local SCRIPT_NAME = 'PPQKissAssistManager'
local CONFIG_MODULE = 'ppqka.config.ppq_g1'

local terminate = false
local isOpen = true
local shouldDraw = true
local dryRunLog = {}
local lastRefresh = 0
local discovery = {
  local_name = 'unknown',
  version = 'unknown',
  peer_count = 0,
  peers = {},
  joined = {},
  groups = {},
}

local ok, configOrError = pcall(require, CONFIG_MODULE)
local config = ok and configOrError or {
  name = 'Config failed to load',
  assist = '',
  groups = {},
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
end

local function render()
  if not isOpen then
    return
  end

  isOpen, shouldDraw = ImGui.Begin('PPQ KissAssist Manager', isOpen)

  if shouldDraw then
    ImGui.Text(config.name or 'Unnamed config')
    ImGui.Text('Assist: ' .. tostring(config.assist or ''))
    ImGui.Text('Current scaffold is dry-run only. No real commands are sent.')
    ImGui.Separator()

    drawDanNetDiscovery()

    ImGui.Separator()

    drawGroupActions()

    ImGui.Separator()
    ImGui.Text('Configured characters')

    for _, character in ipairs(config.characters or {}) do
      drawCharacterRow(character)
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

    if ImGui.Button('Close Script') then
      terminate = true
    end
  end

  ImGui.End()
end

mq.imgui.init(SCRIPT_NAME, render)
refreshDanNetDiscovery()

while not terminate do
  local now = os.time()
  if now - lastRefresh >= 5 then
    refreshDanNetDiscovery()
    lastRefresh = now
  end

  mq.delay(500)
end

mq.imgui.destroy(SCRIPT_NAME)
