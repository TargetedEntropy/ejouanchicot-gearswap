---============================================================================
--- Test of the commands every job shares (shared/utils/core/job_commands.lua, COMMON_COMMANDS.lua)
--- Run from data/: lua5.1 scripts/atelier/job_commands_test.lua
---============================================================================
--- 1. No common word is also a diagnostic word (DEBUG_COMMANDS.lua), a warp alias or ja<n>: the router looks them up
---    one list after the other, so a word in two lists would answer only the first.
--- 2. A word a job tests after JobCommands.shared is never a common word: the shared call would answer it first and
---    the job's branch would never run (COR's colors and WAR's perf were such branches).
--- 3. The shared commands answer in the job's place: handled set, the common router given the job and the words.
--- @file scripts/atelier/job_commands_test.lua
---============================================================================
package.path = './?.lua;' .. package.path
local T = dofile('scripts/lib/testlib.lua')
local check = T.eq

local calls = {}
local function stub(name) return setmetatable({}, {__index = function(_, k) return function(...) calls[#calls + 1] = {name .. '.' .. k, ...} end end}) end
T.module('shared/utils/messages/formatters/ui/message_commands', stub('MessageCommands'))
T.module('shared/utils/messages/message_formatter', stub('MessageFormatter'))
T.module('shared/utils/craft/craft_commands', stub('CraftCommands'))
T.module('shared/utils/core/GEAR_COMMANDS', stub('GearCommands'))
local DEBUG_WORDS = {}
for word in (io.open('shared/utils/core/DEBUG_COMMANDS.lua'):read('*a'):match('DebugCommands%.WORDS = (%b{})') or ''):gmatch('([%w_]+) = ') do
    DEBUG_WORDS[word] = true
end
local Debug = {WORDS = DEBUG_WORDS, run = function() return nil end}
T.module('shared/utils/core/DEBUG_COMMANDS', Debug)
local CC = dofile('shared/utils/core/COMMON_COMMANDS.lua')
local Warp = dofile('shared/utils/warp/warp_command_registry.lua')

-- 1. one list per word
local words = CC.words()
check('the common words are there', #words > 70, true)
for _, w in ipairs(words) do
    T.ok('common word not a diagnostic: ' .. w, not DEBUG_WORDS[w])
    T.ok('common word not a warp alias: ' .. w, not Warp.SET[w] and not (w:find('all$') and Warp.SET[(w:gsub('all$', ''))]))
    T.ok('common word not ja<n>: ' .. w, not w:match('^ja%d*$'))
end

-- 2. every job's words after the shared call
local jobs = 0
for _, f in ipairs(T.files('shared/jobs', '_COMMANDS.lua')) do
    local text = io.open(f):read('*a')
    local fn = text:match('function job_self_command.-\nend\n') or ''
    local after = fn:match('JobCommands%.shared%(.-\n(.*)$')
    if text:find('JobCommands.router(', 1, true) then
        jobs = jobs + 1
    elseif after then
        jobs = jobs + 1
        for word in after:gmatch("command == '([%w_]+)'") do
            T.ok(f:match('[^/]+$') .. ': ' .. word .. ' is not a common word (it would never reach the job)',
                not CC.is_common_command(word))
        end
    else
        T.ok(f .. ' goes through JobCommands', false)
    end
end
check('every job goes through JobCommands', jobs, 22)

-- 3. the shared commands
local routed
CC.is_common_command = function(w) return w == 'reload' end
CC.handle_command = function(...) routed = {...} return true end
T.module('shared/utils/core/COMMON_COMMANDS', CC)
T.module('shared/utils/core/WATCHDOG_COMMANDS', {is_watchdog_command = function(w) return w == 'watchdog' end,
    handle_command = function() return true end})
T.module('shared/utils/ui/UI_COMMANDS', {is_ui_command = function(w) return w == 'ui' end, handle_ui_command = function() end})
T.module('shared/utils/core/CYCLE_HANDLER', {handle_cyclestate = function() return 'cycled' end})
local JC = dofile('shared/utils/core/job_commands.lua')
local ea = {}
check('reload: answered', JC.shared('reload', {'Reload', 'now'}, ea, 'WAR'), true)
check('  handled', ea.handled, true)
check('  the router told the job', routed[2], 'WAR')
check('  and given the words after the command', routed[3], 'now')
ea = {}
check('watchdog: answered', JC.shared('watchdog', {'watchdog'}, ea, 'PLD'), true)
check('  handled', ea.handled, true)
ea = {}
check('cyclestate: what the cycle handler says', (JC.shared('cyclestate', {'cyclestate', 'X'}, ea, 'GEO') and ea.handled), 'cycled')
ea = {}
check('a job word: not answered', JC.shared('indi', {'indi'}, ea, 'GEO'), false)
check('  not handled', ea.handled, nil)

T.done()
