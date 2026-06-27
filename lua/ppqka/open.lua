local mq = require('mq')

local MANAGER_SCRIPT = 'ppqka/ppq_ka_manager'

local status = tostring(mq.TLO.Lua.Script(MANAGER_SCRIPT).Status() or '')

if status == 'RUNNING' then
  mq.cmd('/ppqka')
else
  mq.cmd('/lua run ' .. MANAGER_SCRIPT)
end
