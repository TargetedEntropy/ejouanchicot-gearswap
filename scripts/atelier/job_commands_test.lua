---============================================================================
--- Test of the commands every job shares (shared/utils/core/job_commands.lua, COMMON_COMMANDS.lua)
--- Run from data/: lua5.1 scripts/atelier/job_commands_test.lua
---============================================================================
--- 1. No common word is also a diagnostic word (DEBUG_COMMANDS.lua), a warp alias or ja<n>: the router looks them up
---    one list after the other, so a word in two lists would answer only the first.
--- 2. A word in a job's `words` is never a common word: the shared call would answer it first and the job's
---    handler would never run (COR's colors and WAR's perf were such words).
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

-- 2. every job's own words: never a common word (the shared call would answer it first and the job's handler would
--    never run: COR's colors and WAR's perf were such words), except the ones a job puts in `first`
local permissive = function() return setmetatable({}, {__index = function() return function() end end, __call = function() end}) end
-- the tables each job gives the router, captured by a router of the test's own
local specs = {}
local JobCommandsStub = setmetatable({router = function(job, spec) specs[job] = spec or {} return function() end end},
    {__index = function() return function() return function() end end end})
local jobs = 0
for _, f in ipairs(T.files('shared/jobs', '_COMMANDS.lua')) do
    local job = f:match('([%u]+)_COMMANDS%.lua$')
    local env = setmetatable({}, {__index = function(_, k) return _G[k] ~= nil and _G[k] or permissive() end})
    env._G = env
    env.require = function(name)
        if name == 'shared/utils/core/job_commands' then return JobCommandsStub end
        return package.loaded[name] or permissive()
    end
    local chunk = assert(loadfile(f))
    setfenv(chunk, env)
    local ok, err = pcall(chunk)
    T.ok(job .. '_COMMANDS loads', ok, err)
    local spec = specs[job]
    if T.ok(job .. ' goes through JobCommands.router', spec ~= nil and env.job_self_command ~= nil) then
        jobs = jobs + 1
        for word in pairs(spec.words or {}) do
            T.ok(job .. ': ' .. word .. ' is not a common word (it would never reach the job)',
                not CC.is_common_command(word))
            T.ok(job .. ': ' .. word .. ' is lower case (the router looks the word up in lower case)', word == word:lower())
        end
        for word in pairs(spec.first or {}) do
            T.ok(job .. ': first ' .. word .. ' is lower case', word == word:lower())
        end
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

-- 4. the router: first, then the shared words, then words, then other; it answers unless the handler returns PASS
local seen = {}
local function mark(name, ret) return function(cmdParams, command) seen[#seen + 1] = name .. ':' .. command return ret end end
local loads = 0
local router = JC.router('TST', {
    load = function() loads = loads + 1 end,
    first = {reload = mark('first'), aoe = function(cmdParams) if cmdParams[2] then return JC.PASS end seen[#seen + 1] = 'aoe' end},
    words = {rune = mark('word'), cycle = mark('word', JC.PASS), plain = mark('word', false)},
    other = function(cmdParams, command) seen[#seen + 1] = 'other:' .. command if command == 'nothing' then return JC.PASS end end,
})
routed = nil
ea = {}
router({'Reload'}, ea)
check('a first word wins over the shared one', seen[1], 'first:reload')
check('  the shared router not asked', routed, nil)
check('  answered', ea.handled, true)
ea = {}
router({'rune'}, ea)
check('a job word', seen[2], 'word:rune')
check('  answered', ea.handled, true)
ea = {}
router({'cycle', 'Storm'}, ea)
check('a job word returning PASS', seen[3], 'word:cycle')
check('  left to Mote', ea.handled, nil)
ea = {}
router({'ws3'}, ea)
check('any other word goes to other', seen[4], 'other:ws3')
check('  answered', ea.handled, true)
ea = {}
router({'nothing'}, ea)
check('other returning PASS: left to Mote', ea.handled, nil)
ea = {}
router({'plain'}, ea)
check('a handler returning false (a helper\'s result): still answered', ea.handled, true)
ea = {}
router({'aoe'}, ea)
check('first: bare aoe is the job\'s', seen[7], 'aoe')
check('  answered', ea.handled, true)
ea = {}
router({'aoe', 'sneak'}, ea)
check('first returning PASS lets the word through (aoe is no shared word here: on to other)', seen[8], 'other:aoe')
router({}, {})
check('no word: nothing, not even the load', loads, 8)

-- 5. the weaponskill slots
local cast
package.loaded['shared/utils/weaponskill/ws_slots'] = {cast = function(n) cast = n end}
local ws, pld_ws = JC.ws_slots(), JC.ws_slots(true)
check('ws2: slot 2', (ws({'ws2'}, 'ws2') ~= JC.PASS) and cast, 2)
check('ws alone: not a slot', ws({'ws'}, 'ws'), JC.PASS)
cast = nil
check('ws alone on PLD: slot 1', (pld_ws({'ws'}, 'ws') ~= JC.PASS) and cast, 1)
check('another word: not a slot', ws({'wsx'}, 'wsx'), JC.PASS)

T.done()
