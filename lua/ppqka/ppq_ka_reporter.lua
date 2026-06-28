local mq = require('mq')

local SCRIPT_NAME = 'PPQKAReporter'
local REPORTER_VARIABLE = 'PPQKA_Status'
local HEARTBEAT_VARIABLE = 'PPQKA_ReporterHeartbeat'
local UPDATE_DELAY_MS = 1000

local function safeTlo(getter, fallback)
  local success, value = pcall(getter)
  if success and value ~= nil then
    return value
  end

  return fallback
end

local function cleanText(value)
  local text = tostring(value or '')
  local normalized = string.lower(text)

  if text == ''
    or normalized == 'null'
    or normalized == 'nil'
    or normalized == 'unknown'
    or normalized == 'unavailable' then
    return ''
  end

  return text
end

local function cleanName(value)
  local text = cleanText(value)
  local normalized = string.lower(text)

  if text == '' or normalized == 'true' or normalized == 'false' or text:match('^%d+$') then
    return ''
  end

  return text
end

local function encode(value)
  return cleanText(value):gsub('.', function(character)
    return string.format('%02X', string.byte(character))
  end)
end

local function boolText(value)
  if value == true or tostring(value) == 'TRUE' or tostring(value) == 'true' then
    return 'true'
  end

  if value == false or tostring(value) == 'FALSE' or tostring(value) == 'false' then
    return 'false'
  end

  return ''
end

local function ensureReporterVariable()
  if tostring(mq.parse('${Defined[' .. REPORTER_VARIABLE .. ']}')) ~= 'TRUE' then
    mq.cmdf('/declare %s string outer ""', REPORTER_VARIABLE)
  end

  if tostring(mq.parse('${Defined[' .. HEARTBEAT_VARIABLE .. ']}')) ~= 'TRUE' then
    mq.cmdf('/declare %s string outer "0"', HEARTBEAT_VARIABLE)
  end
end

local function readHeartbeat()
  return tonumber(safeTlo(function()
    return mq.parse('${' .. HEARTBEAT_VARIABLE .. '}')
  end, nil)) or 0
end

local function groupMemberName(index)
  return cleanName(safeTlo(function()
    return mq.TLO.Group.Member(index).Name()
  end, ''))
end

local function groupRoster(groupMembers)
  local names = {}

  if (tonumber(groupMembers) or 0) <= 0 then
    return ''
  end

  for index = 0, 5 do
    local memberName = groupMemberName(index)

    if memberName ~= '' then
      table.insert(names, memberName)
    end
  end

  return table.concat(names, ',')
end

local function buildStatus()
  local groupMembers = safeTlo(function()
    return mq.TLO.Group.Members()
  end, 0)

  local fields = {
    v = '1',
    name = cleanName(safeTlo(function()
      return mq.TLO.Me.Name()
    end, '')),
    macro = cleanText(safeTlo(function()
      return mq.TLO.Macro.Name()
    end, '')),
    paused = boolText(safeTlo(function()
      return mq.TLO.Macro.Paused()
    end, nil)),
    ini = cleanText(safeTlo(function()
      return mq.TLO.Macro.Variable('IniFile')()
    end, '')),
    group_members = tostring(groupMembers or 0),
    leader = cleanName(safeTlo(function()
      return mq.TLO.Group.Leader.Name()
    end, '')),
    ma = cleanName(safeTlo(function()
      return mq.TLO.Group.MainAssist.Name()
    end, '')),
    rma = cleanName(safeTlo(function()
      return mq.TLO.Raid.MainAssist.Name()
    end, '')),
    roster = groupRoster(groupMembers),
    ts = tostring(os.time()),
  }

  local parts = {}

  for _, key in ipairs({ 'v', 'name', 'macro', 'paused', 'ini', 'group_members', 'leader', 'ma', 'rma', 'roster', 'ts' }) do
    table.insert(parts, key .. '~' .. encode(fields[key]))
  end

  return table.concat(parts, '|')
end

local function publishStatus()
  ensureReporterVariable()
  mq.cmd('/varset ' .. REPORTER_VARIABLE .. ' ' .. buildStatus())
  mq.cmd('/varset ' .. HEARTBEAT_VARIABLE .. ' ' .. tostring(os.time()))
end

ensureReporterVariable()

if os.time() - readHeartbeat() <= 3 then
  print(string.format('[%s] already running', SCRIPT_NAME))
  return
end

print(string.format('[%s] started', SCRIPT_NAME))

while true do
  local ok, errorMessage = pcall(publishStatus)

  if not ok then
    print(string.format('[%s] publish failed: %s', SCRIPT_NAME, tostring(errorMessage)))
  end

  mq.delay(UPDATE_DELAY_MS)
end
