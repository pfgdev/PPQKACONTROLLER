local mq = require('mq')
require('ImGui')

local SCRIPT_NAME = 'PPQKissAssistManager'
local CONFIG_MODULE = 'ppqka.config.ppq_g1'
local REPORTER_SCRIPT = 'ppqka/ppq_ka_reporter'
local REPORTER_VARIABLE = 'PPQKA_Status'

local terminate = false
local isOpen = true
local shouldDraw = true
local showDebug = false
local selectedLoadoutKey = nil
local pendingChanges = {}
local dryRunLog = {}
local commandQueue = {}
local lastRefresh = 0
local lastStatusQuery = 0
local STATUS_QUERY_SECONDS = 8
local STATUS_READ_DELAY_SECONDS = 2
local GROUP_UNGROUP_CONFIRM_READS = 3
local STATUS_QUERIES = {
  REPORTER_VARIABLE,
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
local currentGroupViews
local groupFirstSeen = {}
local groupFirstSeenCounter = 0
local reporterStarted = {}

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

local function normalizePeerName(name)
  return string.lower(tostring(name or ''))
end

local function cleanTloName(value)
  local text = tostring(value or '')
  local normalized = string.lower(text)

  if text == ''
    or normalized == 'null'
    or normalized == 'nil'
    or normalized == 'unknown'
    or normalized == 'unavailable'
    or normalized == 'true'
    or normalized == 'false'
    or text:match('^%d+$') then
    return nil
  end

  return text
end

local function cleanReportedText(value)
  local text = tostring(value or '')
  local normalized = string.lower(text)

  if text == ''
    or normalized == 'null'
    or normalized == 'nil'
    or normalized == 'unknown'
    or normalized == 'unavailable' then
    return nil
  end

  return text
end

local function reportedBool(value)
  local normalized = string.lower(tostring(value or ''))

  if normalized == 'true' then
    return true
  end

  if normalized == 'false' then
    return false
  end

  return nil
end

local function allKnownPeers()
  local seen = {}
  local peers = {}
  local localName = cleanTloName(discovery.local_name)

  if localName then
    seen[normalizePeerName(localName)] = true
    table.insert(peers, localName)
  end

  for _, peer in ipairs(discovery.peers or {}) do
    local peerName = cleanTloName(peer)
    local key = normalizePeerName(peerName)

    if peerName and not seen[key] then
      seen[key] = true
      table.insert(peers, peerName)
    end
  end

  table.sort(peers)
  return peers
end

local function allDisplayPeers()
  return allKnownPeers()
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

local function formatRoster(roster)
  local names = {}

  for key, name in pairs(roster or {}) do
    table.insert(names, type(name) == 'string' and name or key)
  end

  return formatList(names)
end

local function decodeReporterValue(value)
  local text = tostring(value or '')

  return text
    :gsub('%%20', ' ')
    :gsub('%%2C', ',')
    :gsub('%%7E', '~')
    :gsub('%%7C', '|')
    :gsub('%%25', '%%')
end

local function parseReporterPayload(payload)
  local text = cleanReportedText(payload)

  if not text then
    return nil
  end

  local report = {}

  for field in text:gmatch('[^|]+') do
    local key, value = field:match('^([^~]+)~(.*)$')

    if key then
      report[key] = decodeReporterValue(value)
    end
  end

  if report.v ~= '1' then
    return nil
  end

  return report
end

local function rosterFromReporter(report)
  local roster = {}

  for memberName in tostring((report and report.roster) or ''):gmatch('[^,]+') do
    local cleanName = cleanTloName(memberName)

    if cleanName then
      roster[normalizePeerName(cleanName)] = cleanName
    end
  end

  return roster
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

local function profileForIni(characterName, ini)
  local reportedIni = cleanReportedText(ini)

  if not reportedIni then
    return nil
  end

  local normalizedIni = string.lower(reportedIni)

  for _, profile in ipairs(profileEntriesFor(characterName)) do
    if string.lower(profile.ini or '') == normalizedIni then
      return profile
    end
  end

  return {
    key = nil,
    label = reportedIni,
    ini = reportedIni,
  }
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

local function isLocalPeer(characterName)
  return normalizePeerName(characterName) == normalizePeerName(discovery.local_name)
end

local function groupMemberQuery(index)
  return 'Group.Member[' .. tostring(index) .. '].Name'
end

local function readLocalGroupRoster(memberCount)
  local roster = {}

  if (tonumber(memberCount) or 0) <= 0 then
    return roster
  end

  for index = 0, 5 do
    local memberName = cleanTloName(safeTlo(groupMemberQuery(index), function()
      return mq.TLO.Group.Member(index).Name()
    end, nil))

    if memberName then
      roster[normalizePeerName(memberName)] = memberName
    end
  end

  return roster
end

local function readLocalMacroStatus()
  local groupMembers = safeTlo('Group.Members', function()
    return mq.TLO.Group.Members()
  end, 0)

  return {
    macro_name = safeTlo('Macro.Name', function()
      return mq.TLO.Macro.Name()
    end, ''),
    macro_paused = safeTlo('Macro.Paused', function()
      return mq.TLO.Macro.Paused()
    end, nil),
    kiss_ini = safeTlo('Macro.Variable[IniFile]', function()
      return mq.TLO.Macro.Variable('IniFile')()
    end, nil),
    group_members = groupMembers,
    group_leader = safeTlo('Group.Leader.Name', function()
      return mq.TLO.Group.Leader.Name()
    end, ''),
    group_main_assist = safeTlo('Group.MainAssist.Name', function()
      return mq.TLO.Group.MainAssist.Name()
    end, ''),
    group_roster = readLocalGroupRoster(groupMembers),
    query_ok = true,
  }
end

local function readPeerQuery(peer, query)
  return safeTlo('DanNet[' .. tostring(peer) .. '].Q[' .. query .. ']', function()
    return mq.TLO.DanNet(peer).Q(query)()
  end, nil)
end

local function readLocalReporterPayload()
  return safeTlo(REPORTER_VARIABLE, function()
    return mq.parse('${' .. REPORTER_VARIABLE .. '}')
  end, nil)
end

local function applyReporterPayload(status, payload)
  local report = parseReporterPayload(payload)

  if not report then
    return false
  end

  status.reporter_seen = true
  status.reporter_raw = tostring(payload or '')
  status.reporter_read_at = os.time()
  status.macro_name = cleanReportedText(report.macro) or ''
  status.macro_paused = cleanReportedText(report.paused)
  status.kiss_ini = cleanReportedText(report.ini)
  status.group_members = cleanReportedText(report.group_members) or '0'
  status.group_leader = cleanReportedText(report.leader)
  status.group_main_assist = cleanReportedText(report.ma)
  status.group_roster = rosterFromReporter(report)
  status.group_read_at = os.time()
  status.read_at = os.time()
  status.query_ok = true
  return true
end

local function startReporterForPeer(peer)
  local peerKey = normalizePeerName(peer)

  if reporterStarted[peerKey] then
    return
  end

  reporterStarted[peerKey] = true

  if isLocalPeer(peer) then
    mq.cmd('/lua run ' .. REPORTER_SCRIPT)
  else
    mq.cmdf('/dex %s /lua run %s', peer, REPORTER_SCRIPT)
  end
end

local function startReporters()
  for _, peer in ipairs(allKnownPeers()) do
    startReporterForPeer(peer)
  end
end

local function submitPeerStatusQueries(peer)
  if isLocalPeer(peer) then
    local cached = statusCache[peer] or {}

    if not applyReporterPayload(cached, readLocalReporterPayload()) then
      local localStatus = readLocalMacroStatus()
      cached.macro_name = localStatus.macro_name
      cached.macro_paused = localStatus.macro_paused
      cached.kiss_ini = localStatus.kiss_ini
      cached.group_members = localStatus.group_members
      cached.group_leader = localStatus.group_leader
      cached.group_main_assist = localStatus.group_main_assist
      cached.group_roster = localStatus.group_roster
      cached.query_ok = localStatus.query_ok
    end

    cached.query_pending = false
    cached.requested_at = os.time()
    cached.read_at = os.time()
    cached.group_read_at = os.time()
    cached.read_after = nil
    statusCache[peer] = cached
    return
  end

  local cached = statusCache[peer] or {}
  cached.requested_at = os.time()
  cached.read_after = cached.requested_at + STATUS_READ_DELAY_SECONDS
  cached.query_pending = true
  cached.query_ok = cached.read_at ~= nil
  statusCache[peer] = cached

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

    if not applyReporterPayload(cached, readLocalReporterPayload()) then
      local localStatus = readLocalMacroStatus()
      cached.macro_name = localStatus.macro_name
      cached.macro_paused = localStatus.macro_paused
      cached.kiss_ini = localStatus.kiss_ini
      cached.group_members = localStatus.group_members
      cached.group_leader = localStatus.group_leader
      cached.group_main_assist = localStatus.group_main_assist
      cached.group_roster = localStatus.group_roster
      cached.query_ok = localStatus.query_ok
    end

    cached.query_pending = false
    cached.requested_at = os.time()
    cached.read_at = os.time()
    cached.group_read_at = os.time()
    cached.read_after = nil
    statusCache[peer] = cached
    return cached
  end

  local status = statusCache[peer] or {}

  if not status.requested_at then
    submitPeerStatusQueries(peer)
    return statusCache[peer] or status
  end

  if status.read_after and os.time() < status.read_after then
    return status
  end

  local reporterPayload = readPeerQuery(peer, REPORTER_VARIABLE)
  applyReporterPayload(status, reporterPayload)

  status.query_pending = false
  status.read_after = nil
  status.query_ok = status.reporter_seen == true
  statusCache[peer] = status
  return status
end

local function statusFor(characterName)
  local status = updatePeerStatusFromQueries(characterName)

  if status.query_pending and not status.read_at then
    return 'checking'
  end

  local macroName = tostring(status.macro_name or '')
  local normalizedMacroName = string.lower(macroName)

  if normalizedMacroName == '' or normalizedMacroName == 'null' then
    if status.query_ok then
      return 'inactive'
    end

    return 'unknown'
  end

  if string.find(normalizedMacroName, 'kiss') then
    if reportedBool(status.macro_paused) then
      return 'paused'
    end

    return 'active'
  end

  if status.query_ok then
    return 'inactive'
  end

  return 'unknown'
end

local function groupOrderFor(key)
  if not groupFirstSeen[key] then
    groupFirstSeenCounter = groupFirstSeenCounter + 1
    groupFirstSeen[key] = groupFirstSeenCounter
  end

  return groupFirstSeen[key]
end

local function localGroupSnapshot()
  local memberCount = tonumber(safeTlo('Group.Members', function()
    return mq.TLO.Group.Members()
  end, 0)) or 0

  if memberCount <= 0 then
    return nil
  end

  local leader = cleanTloName(safeTlo('Group.Leader.Name', function()
    return mq.TLO.Group.Leader.Name()
  end, nil))

  if not leader then
    return nil
  end

  local members = {}

  for index = 0, memberCount do
    local memberName = cleanTloName(safeTlo('Group.Member[' .. tostring(index) .. '].Name', function()
      return mq.TLO.Group.Member(index).Name()
    end, nil))

    if memberName then
      members[normalizePeerName(memberName)] = true
    end
  end

  local mainAssist = cleanTloName(safeTlo('Group.MainAssist.Name', function()
    return mq.TLO.Group.MainAssist.Name()
  end, nil))
  local key = 'group:' .. normalizePeerName(leader)

  return {
    key = key,
    label = leader .. "'s Group",
    leader = leader,
    main_assist = mainAssist,
    members = members,
    grouped = true,
  }
end

local function rawPeerGroupInfo(status)
  local memberCount = tonumber(status.group_members) or 0
  local leader = cleanTloName(status.group_leader)
  local mainAssist = cleanTloName(status.group_main_assist)
  local roster = status.group_roster or {}

  if memberCount > 0 and leader then
    if roster[normalizePeerName(leader)] == nil then
      roster[normalizePeerName(leader)] = leader
    end

    return {
      key = 'group:' .. normalizePeerName(leader),
      label = leader .. "'s Group",
      leader = leader,
      main_assist = mainAssist,
      members = roster,
      grouped = true,
    }
  end

  return {
    key = 'ungrouped',
    label = 'Ungrouped',
    grouped = false,
  }
end

local function stablePeerGroupInfo(peer)
  local status = updatePeerStatusFromQueries(peer)
  local rawInfo = rawPeerGroupInfo(status)
  local state = status.group_state or {
    ungrouped_reads = 0,
    last_group_read_at = nil,
  }
  local hasFreshGroupRead = status.group_read_at and status.group_read_at ~= state.last_group_read_at

  if rawInfo.grouped then
    state.info = rawInfo
    state.ungrouped_reads = 0
    state.last_group_read_at = status.group_read_at
    status.group_state = state
    return rawInfo
  end

  if hasFreshGroupRead then
    state.ungrouped_reads = (state.ungrouped_reads or 0) + 1
    state.last_group_read_at = status.group_read_at
  end

  if state.info and state.info.grouped and (state.ungrouped_reads or 0) < GROUP_UNGROUP_CONFIRM_READS then
    status.group_state = state
    return state.info
  end

  state.info = rawInfo
  status.group_state = state
  return rawInfo
end

local function actualGroupViews()
  local grouped = {}
  local localGroup = localGroupSnapshot()
  local allPeers = allKnownPeers()
  local knownPeers = {}
  local assignedPeers = {}
  local ungrouped = {
    key = 'ungrouped',
    label = 'Ungrouped',
    peers = {},
    source = 'live',
    order = 999999,
  }
  local localGroupKey = nil

  for _, peer in ipairs(allPeers) do
    knownPeers[normalizePeerName(peer)] = peer
  end

  for _, peer in ipairs(allPeers) do
    local peerKey = normalizePeerName(peer)
    local info = localGroup and localGroup.members[peerKey] and localGroup or stablePeerGroupInfo(peer)

    if info.grouped then
      local group = grouped[info.key]

      if not group then
        group = {
          key = info.key,
          label = info.label,
          leader = info.leader,
          main_assist = info.main_assist,
          peers = {},
          source = 'live',
          order = groupOrderFor(info.key),
        }
        grouped[info.key] = group
      elseif info.main_assist and not group.main_assist then
        group.main_assist = info.main_assist
      end

      local addedRosterMember = false

      for memberKey, memberName in pairs(info.members or {}) do
        local displayName = knownPeers[memberKey]

        if not displayName and type(memberName) == 'string' then
          displayName = memberName
        end

        if displayName and not assignedPeers[normalizePeerName(displayName)] then
          assignedPeers[normalizePeerName(displayName)] = true
          table.insert(group.peers, displayName)
          addedRosterMember = true
        end
      end

      if not addedRosterMember and not assignedPeers[peerKey] then
        assignedPeers[peerKey] = true
        table.insert(group.peers, peer)
      end

      if isLocalPeer(peer) or (localGroup and info.key == localGroup.key) then
        localGroupKey = info.key
      end
    end
  end

  for _, peer in ipairs(allPeers) do
    if not assignedPeers[normalizePeerName(peer)] then
      table.insert(ungrouped.peers, peer)
    end
  end

  local groups = {}

  for _, group in pairs(grouped) do
    table.sort(group.peers)
    table.insert(groups, group)
  end

  table.sort(groups, function(left, right)
    if localGroupKey then
      if left.key == localGroupKey and right.key ~= localGroupKey then
        return true
      end

      if right.key == localGroupKey and left.key ~= localGroupKey then
        return false
      end
    end

    if left.order == right.order then
      return left.label < right.label
    end

    return left.order < right.order
  end)

  if #ungrouped.peers > 0 then
    table.sort(ungrouped.peers)
    table.insert(groups, ungrouped)
  end

  return groups
end

currentGroupViews = actualGroupViews

local function targetMatchesCurrent(characterName, kind, profileKey)
  local status = statusFor(characterName)

  if status == 'inactive' and kind == 'manual' then
    return true
  end

  if (status == 'active' or status == 'paused') and kind == 'profile' then
    local reportedProfile = profileForIni(characterName, (statusCache[characterName] or {}).kiss_ini)

    if reportedProfile and reportedProfile.key == profileKey then
      return true
    end
  end

  if (status == 'active' or status == 'paused') and kind == 'profile' and selectedProfileKeyFor(characterName) == profileKey then
    return true
  end

  return false
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

local function loadCharacterProfile(characterName, profile, assist, endDelayMs, startDelayMs)
  if not profile or not profile.ini or profile.ini == '' or profile.ini == 'unknown' then
    logAction('SKIP', 'No configured INI for ' .. tostring(characterName))
    return
  end

  enqueueCommand(string.format('/dex %s /end', characterName), endDelayMs, characterName)
  enqueueCommand(string.format('/dex %s /mac kissassist ini %s assist ma %s', characterName, profile.ini, assist or config.assist or ''), startDelayMs, characterName)
end

local function pendingChangeFor(characterName)
  return pendingChanges[characterConfigKey(characterName)]
end

local function clearPendingChange(characterName)
  pendingChanges[characterConfigKey(characterName)] = nil
end

local function clearPendingChanges()
  pendingChanges = {}
end

local function pendingChangeCount()
  local count = 0

  for _ in pairs(pendingChanges) do
    count = count + 1
  end

  return count
end

local function stageManualTarget(characterName)
  if targetMatchesCurrent(characterName, 'manual') then
    clearPendingChange(characterName)
    return false
  end

  pendingChanges[characterConfigKey(characterName)] = {
    character = characterName,
    kind = 'manual',
  }

  return true
end

local function stageProfileTarget(characterName, profileKey, assist)
  if targetMatchesCurrent(characterName, 'profile', profileKey) then
    clearPendingChange(characterName)
    return false
  end

  pendingChanges[characterConfigKey(characterName)] = {
    character = characterName,
    kind = 'profile',
    profile = profileKey,
    assist = assist,
  }

  return true
end

local function stageLoadout(loadout)
  if not loadout then
    logAction('SKIP', 'No loadout selected')
    return
  end

  local entries = loadoutCharacterEntries(loadout)
  local stagedCount = 0

  for _, entry in ipairs(entries) do
    if stageProfileTarget(entry.character, entry.profile, loadout.assist or config.assist) then
      stagedCount = stagedCount + 1
    end
  end

  logAction('STAGE', 'Staged ' .. tostring(stagedCount) .. ' targets from ' .. tostring(loadout.label or loadout.key))
end

local function stageUnloadLoadout(loadout)
  if not loadout then
    logAction('SKIP', 'No loadout selected')
    return
  end

  local stagedCount = 0

  for _, entry in ipairs(loadoutCharacterEntries(loadout)) do
    if stageManualTarget(entry.character) then
      stagedCount = stagedCount + 1
    end
  end

  logAction('STAGE', 'Staged ' .. tostring(stagedCount) .. ' manual targets from ' .. tostring(loadout.label or loadout.key))
end

local function applyPendingChanges()
  local entries = {}
  local targets = {}

  for key, change in pairs(pendingChanges) do
    table.insert(entries, change)
    targets[key] = true
  end

  if #entries == 0 then
    logAction('SKIP', 'No pending changes')
    return
  end

  table.sort(entries, function(left, right)
    return left.character < right.character
  end)

  clearQueuedCommandsForTargets(targets)

  local endSpacingMs = timingValue('loadout_end_spacing_ms', DEFAULT_LOADOUT_END_SPACING_MS)
  local startSpacingMs = timingValue('loadout_start_spacing_ms', DEFAULT_LOADOUT_START_SPACING_MS)
  local restartDelayMs = timingValue('end_to_start_delay_ms', DEFAULT_END_TO_START_DELAY_MS)

  for index, change in ipairs(entries) do
    local endDelayMs = (index - 1) * endSpacingMs

    if change.kind == 'manual' then
      enqueueCommand(string.format('/dex %s /end', change.character), endDelayMs, change.character)
    elseif change.kind == 'profile' then
      config.active_profiles[characterConfigKey(change.character)] = change.profile
      loadCharacterProfile(
        change.character,
        profileForKey(change.character, change.profile),
        change.assist or config.assist,
        endDelayMs,
        restartDelayMs + ((index - 1) * startSpacingMs)
      )
    end
  end

  logAction('APPLY', 'Applied ' .. tostring(#entries) .. ' pending changes')
  clearPendingChanges()
end

local function changeCountText(count)
  if count == 1 then
    return '1 Change'
  end

  return tostring(count) .. ' Changes'
end

local function drawLoadoutControls()
  local entries = loadoutEntries()
  local loadout = selectedLoadout()
  local changeCount = pendingChangeCount()

  ImGui.Text('Current Loadout')
  ImGui.SameLine(120)

  if #entries == 0 then
    ImGui.Text('none configured')
    return
  end

  ImGui.SetNextItemWidth(190)

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

  if ImGui.Button('Stage Loadout') then
    stageLoadout(selectedLoadout())
  end

  ImGui.SameLine()

  if ImGui.Button('Stage Unload') then
    stageUnloadLoadout(selectedLoadout())
  end

  ImGui.SameLine(520)
  ImGui.Text(changeCountText(changeCount) .. ' pending')
  ImGui.SameLine()

  if ImGui.Button('Clear') then
    clearPendingChanges()
  end

  ImGui.SameLine()

  if ImGui.Button('Apply ' .. changeCountText(changeCount)) then
    applyPendingChanges()
  end
end

local function drawStatusHeader()
  ImGui.Text('Character')
  ImGui.SameLine(180)
  ImGui.Text('Current behavior')
  ImGui.SameLine(380)
  ImGui.Text('Target behavior')
end

local function currentBehaviorFor(characterName)
  local status = statusFor(characterName)
  local reportedStatus = statusCache[characterName] or {}
  local selectedProfile = profileForIni(characterName, reportedStatus.kiss_ini) or selectedProfileFor(characterName)

  if status == 'active' then
    return selectedProfile.label, selectedProfile
  end

  if status == 'paused' then
    return 'Paused: ' .. selectedProfile.label, selectedProfile
  end

  if status == 'checking' then
    return 'Checking', selectedProfile
  end

  if status == 'unknown' then
    return 'Unknown', selectedProfile
  end

  return 'Manual', selectedProfile
end

local function pendingChangeLabel(characterName)
  local change = pendingChangeFor(characterName)

  if not change then
    return 'No Change'
  end

  if change.kind == 'manual' then
    return 'Manual'
  end

  if change.kind == 'profile' then
    return profileForKey(characterName, change.profile).label
  end

  return 'No Change'
end

local function drawTargetDropdown(characterName)
  local entries = profileEntriesFor(characterName)
  local pending = pendingChangeFor(characterName)

  ImGui.SetNextItemWidth(230)

  if ImGui.BeginCombo('##target_' .. characterName, pendingChangeLabel(characterName)) then
    if ImGui.Selectable('No Change', pending == nil) then
      clearPendingChange(characterName)
    end

    if pending == nil then
      ImGui.SetItemDefaultFocus()
    end

    local manualSelected = pending and pending.kind == 'manual'
    if ImGui.Selectable('Manual', manualSelected) then
      if targetMatchesCurrent(characterName, 'manual') then
        clearPendingChange(characterName)
      else
        stageManualTarget(characterName)
      end
    end

    if manualSelected then
      ImGui.SetItemDefaultFocus()
    end

    if #entries > 0 and ImGui.Selectable('-----##target_separator_' .. characterName, false) then
      clearPendingChange(characterName)
    end

    for _, entry in ipairs(entries) do
      local isSelected = pending and pending.kind == 'profile' and pending.profile == entry.key

      if ImGui.Selectable(entry.label, isSelected) then
        if targetMatchesCurrent(characterName, 'profile', entry.key) then
          clearPendingChange(characterName)
        else
          stageProfileTarget(characterName, entry.key, (selectedLoadout() and selectedLoadout().assist) or config.assist)
        end
      end

      if isSelected then
        ImGui.SetItemDefaultFocus()
      end
    end

    ImGui.EndCombo()
  end

  if ImGui.IsItemHovered() and pending and pending.kind == 'profile' then
    ImGui.SetTooltip(profileForKey(characterName, pending.profile).ini)
  end
end

local function drawStatusRow(characterName)
  local pending = pendingChangeFor(characterName)
  local currentBehavior, currentProfile = currentBehaviorFor(characterName)
  local displayName = pending and ('* ' .. characterName) or characterName

  ImGui.Text(displayName)
  ImGui.SameLine(180)
  ImGui.Text(currentBehavior)

  if ImGui.IsItemHovered() then
    ImGui.SetTooltip(currentProfile.ini)
  end

  ImGui.SameLine(380)
  drawTargetDropdown(characterName)

  if pending then
    ImGui.SameLine(620)
    if ImGui.Button('X##clear_target_' .. characterName) then
      clearPendingChange(characterName)
    end
  end
end

local function drawStatusOverview()
  ImGui.Text(config.name or 'PPQ KissAssist Manager')
  drawLoadoutControls()
  ImGui.Text('Status overview')
  ImGui.Separator()

  for _, group in ipairs(currentGroupViews()) do
    local peers = group.peers or {}

    ImGui.Text(group.label or group.peers or 'Group')
    ImGui.SameLine(150)
    ImGui.Text('Peers: ' .. tostring(#peers))
    if group.main_assist then
      ImGui.SameLine(260)
      ImGui.Text('MA: ' .. group.main_assist)
    end
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

  ImGui.Text('Normal polling query: PPQKA_Status')

  for _, peer in ipairs(allDisplayPeers()) do
    local status = updatePeerStatusFromQueries(peer)
    local probe = pausedProbe.results[peer] or {}
    local groupState = status.group_state or {}

    ImGui.Text(peer)
    ImGui.SameLine(150)
    ImGui.Text('Macro.Name: ' .. tostring(status.macro_name or 'unknown'))
    ImGui.SameLine(360)
    ImGui.Text('Macro.Paused: ' .. tostring(status.macro_paused or 'unknown'))
    ImGui.SameLine(560)
    ImGui.Text('IniFile: ' .. tostring(status.kiss_ini or 'unknown'))
    ImGui.Text('Paused probe: ' .. tostring(probe.value or 'not run'))
    ImGui.SameLine(220)
    ImGui.Text('Probe read: ' .. formatTimestamp(probe.read_at))
    ImGui.SameLine(420)
    ImGui.Text('Reporter: ' .. (status.reporter_seen and ('seen ' .. formatTimestamp(status.reporter_read_at)) or 'not seen'))
    ImGui.Text('Group.Members: ' .. tostring(status.group_members or 'unknown'))
    ImGui.SameLine(180)
    ImGui.Text('Leader: ' .. tostring(status.group_leader or 'unknown'))
    ImGui.SameLine(360)
    ImGui.Text('MA: ' .. tostring(status.group_main_assist or 'unknown'))
    ImGui.SameLine(500)
    ImGui.Text('Ungroup reads: ' .. tostring(groupState.ungrouped_reads or 0))
    ImGui.TextWrapped('Roster: ' .. formatRoster(status.group_roster))

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
      startReporters()
      refreshPeerStatusQueries()
      logDryRun('refresh', 'Read DanNet peers, start reporters, and query reported status')
    end

    ImGui.SameLine()

    if ImGui.Button(showDebug and 'Hide debug' or 'Show debug') then
      showDebug = not showDebug
    end

    ImGui.Text('Status uses PPQ reporters via DanNet. Target changes are staged until Apply is clicked.')
    ImGui.Separator()

    if showDebug then
      drawDanNetDiscovery()

      ImGui.Separator()

      drawGroupActions()

      ImGui.Separator()
      ImGui.Text('Configured characters')

      local characters = config.characters or {}
      if #characters == 0 then
        ImGui.Text('No configured character rows. Top table groups known DanNet peers by live EQ group state.')
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
startReporters()
refreshPeerStatusQueries()
lastStatusQuery = os.time()

while not terminate do
  processCommandQueue()
  updatePausedProbeReads()

  local now = os.time()
  if now - lastRefresh >= 5 then
    refreshDanNetDiscovery()
    startReporters()
    lastRefresh = now
  end

  if now - lastStatusQuery >= STATUS_QUERY_SECONDS and now >= pausedProbe.quiet_until then
    refreshPeerStatusQueries()
    lastStatusQuery = now
  end

  mq.delay(500)
end

mq.imgui.destroy(SCRIPT_NAME)
