---============================================================================
--- Test of the hooks every entry shares (shared/utils/core/entry_kit.lua)
---============================================================================
--- The first macro book and lockstyle come even when the keybinds did not
--- load (the job's files define them only after user_setup), and a newer load
--- drops them, and so does the old sandbox's user_setup() on a subjob change;
--- EntryKit.job defines the six globals in their order: unload releases, then
--- cancels and unbinds; a subjob change goes to JobChangeManager with the job
--- of the game.
---
--- Run from data/: lua5.1 scripts/atelier/entry_kit_test.lua
---
--- @file scripts/atelier/entry_kit_test.lua
--- @author ejouanchicot
--- @version 1.0
--- @date Created: 2026-10-15
---============================================================================

package.path = './?.lua;' .. package.path

local T = dofile('scripts/lib/testlib.lua')
local check = T.eq

-- a clock of our own for coroutine.schedule
local now, queue = 0, {}
coroutine.schedule = function(fn, delay) T.push(queue, {at = now + delay, fn = fn}) end
local function run_until(t)
    while true do
        local nxt = queue[1]
        if not nxt or nxt.at > t then break end
        table.remove(queue, 1)
        now = nxt.at
        nxt.fn()
    end
    now = t
end

player = {main_job = 'WAR', sub_job = 'SAM'}
windower = {_load_gen = 1, ffxi = {get_player = function() return {main_job = 'WAR', sub_job = 'SAM'} end}}
package.loaded['shared/utils/debug/trace_log'] = {log = function() end}

local calls = {}
local JCM = {
    on_job_change = function(main, sub) calls[#calls + 1] = 'change ' .. main .. '/' .. sub end,
    cancel_all = function() calls[#calls + 1] = 'cancel' end,
}
package.loaded['shared/utils/core/job_change_manager'] = JCM

-- char_paths, which entry_kit requires first: a stub, filled in below (section EntryKit.job)
local CharPathsStub = {}
package.loaded['shared/utils/core/char_paths'] = CharPathsStub
local EntryKit = require('shared/utils/core/entry_kit')

-- 1. keybinds failed: the two functions do not exist during user_setup
select_default_macro_book, select_default_lockstyle = nil, nil
EntryKit.macro_and_lockstyle(8)
-- get_sets() then loads the job's files
select_default_macro_book = function() calls[#calls + 1] = 'macro' end
select_default_lockstyle = function() calls[#calls + 1] = 'lockstyle' end
run_until(1)
check('macro book once the job\'s files are there', calls[1], 'macro')
check('lockstyle not yet', calls[2], nil)
run_until(9)
check('lockstyle after its delay', calls[2], 'lockstyle')

-- 2. a newer load before the 0.2 s: nothing from the old one
calls = {}
EntryKit.macro_and_lockstyle(8)
windower._load_gen = 2
run_until(20)
check('a newer load drops the old macro book', #calls, 0)

-- 2b. a subjob change: Mote calls user_setup() again in the old sandbox, with
-- player.sub_job already the new one; the reload sends the book, not this call
calls = {}
windower._load_gen = 3
_G.JobChangeManagerSTATE = {current_sub_job = 'SAM'}
player = {main_job = 'WAR', sub_job = 'DNC'}
EntryKit.macro_and_lockstyle(8)
run_until(40)
check('no macro book from the old sandbox on a subjob change', #calls, 0)
check('reload pending seen', EntryKit.reload_pending(), true)

-- 2c. the reload (state seeded with the new subjob): the book goes out
_G.JobChangeManagerSTATE = {current_sub_job = 'DNC'}
windower.ffxi.get_player = function() return {main_job = 'WAR', sub_job = 'DNC'} end
EntryKit.macro_and_lockstyle(8)
run_until(60)
check('macro book from the reload', calls[1], 'macro')
check('lockstyle from the reload', calls[2], 'lockstyle')

-- 2d. no subjob in the game, or no state seeded: never taken for a change
_G.JobChangeManagerSTATE = {current_sub_job = 'DNC'}
player = {main_job = 'WAR', sub_job = nil}
check('no subjob: no reload pending', EntryKit.reload_pending(), false)
_G.JobChangeManagerSTATE = nil
player = {main_job = 'WAR', sub_job = 'DNC'}
check('no state: no reload pending', EntryKit.reload_pending(), false)
windower.ffxi.get_player = function() return {main_job = 'WAR', sub_job = 'SAM'} end
player = {main_job = 'WAR', sub_job = 'SAM'}

-- the job's files: every file EntryKit.job_files lists exists, and every hook file of a job folder is listed
-- (a hook file nobody includes defines nothing; a listed file missing stops get_sets)
local JOBS = {'BLM', 'BLU', 'BRD', 'BST', 'COR', 'DNC', 'DRG', 'DRK', 'GEO', 'MNK', 'NIN', 'PLD', 'PUP', 'RDM',
    'RNG', 'RUN', 'SAM', 'SCH', 'SMN', 'THF', 'WAR', 'WHM'}
local listed = {}
for _, job in ipairs(JOBS) do
    for _, file in ipairs(EntryKit.job_files(job)) do
        local path = file:gsub('^%.%./', '')
        listed[path] = true
        local f = io.open(path)
        T.ok(job .. ' loads ' .. path .. ', which exists', f ~= nil)
        if f then f:close() end
    end
end
for _, path in ipairs(T.files('shared/jobs', '.lua')) do
    if path:match('^shared/jobs/%l+/functions/[^/]+%.lua$') then
        T.ok(path .. ' is loaded by EntryKit.job_files', listed[path])
    end
end
local war = EntryKit.job_files('WAR')
check('WAR: the buff messages first', war[1], '../shared/utils/messages/formatters/magic/message_buffs.lua')
check('WAR: MOVEMENT after COMMANDS', war[#war], '../shared/jobs/war/functions/WAR_MOVEMENT.lua')
check('BRD: no buff messages', EntryKit.job_files('BRD')[1], '../shared/jobs/brd/functions/BRD_PRECAST.lua')

-- EntryKit.job: the six hooks in their order, with a job's steps at their places
local trace = {}
local function log(what) trace[#trace + 1] = what end
local function stub(name, t) package.loaded[name] = t return t end
CharPathsStub.module = function(kind, name) return 'cfg/' .. name end
CharPathsStub.relative = function(kind, file) return 'sets/' .. file end
CharPathsStub.name = function() return 'Tester' end
stub('cfg/LOCKSTYLE_CONFIG', {initial_load_delay = 8})
stub('cfg/RECAST_CONFIG', {recast = true})
stub('cfg/TST_TP_CONFIG', {tp = true})
stub('cfg/TST_STATES', {configure = function() log('states') end})
stub('cfg/TST_KEYBINDS', {bind_all = function() log('bind') end, unbind_all = function() log('unbind') end})
stub('shared/utils/config/config_loader', {load_ui_config = function() return {init_delay = 3} end})
stub('shared/utils/ui/UI_MANAGER', {smart_init = function(job, delay) log('hud ' .. job .. ' ' .. delay) end,
    update = function() log('hud update') end})
stub('shared/utils/debug/performance_profiler', {start = function() end, mark = function() end, finish = function() end,
    create_timer = function() return function() end end})
stub('shared/utils/data/data_loader', {})
stub('shared/utils/lockstyle/lockstyle_manager', {install = function(job) log('lockstyle ' .. job) end})
stub('shared/utils/macrobook/macrobook_manager', {install = function() end})
stub('shared/utils/dualbox/dualbox_manager', {})
JCM.initialize = function() log('jcm') end
JCM.cancel_all = function() log('cancel') end
JCM.register_lockstyle_cancel = function() end
JCM.on_job_change = function(main, sub) log('change ' .. main .. '/' .. sub) end
include = function(file)
    if file == 'Mote-Include.lua' then
        log('mote')
        user_setup()
        init_gear_sets()
    elseif file:find('sets/') then
        log('sets ' .. file)
    elseif file:find('/jobs/tst/') then
        log('file ' .. file:match('([^/]+)%.lua$'))
    end
end
EntryKit.macro_and_lockstyle = function() log('macro') end
local steps = {}
for _, k in ipairs({'before_mote', 'configs', 'after_load', 'after_sets', 'after_states', 'after_ui', 'after_setup',
        'update', 'unload'}) do
    steps[k] = function(arg) log(k .. (arg ~= nil and (' ' .. tostring(arg == 'next.lua' and arg or type(arg))) or '')) end
end
EntryKit.job('TST', steps)
check('get_sets defined', type(get_sets), 'function')
for _, n in ipairs({'init_gear_sets', 'user_setup', 'job_sub_job_change', 'job_update', 'file_unload'}) do
    check(n .. ' defined', type(_G[n]), 'function')
end
get_sets()
local order = table.concat(trace, ', ')
check('get_sets order', order:match('^(.-), states'), 'before_mote, mote')
T.ok('user_setup: states, its step, keys, HUD, after_ui, JobChangeManager, macro book, after_setup',
    order:find('states, after_states, bind, hud TST 3, after_ui table, jcm, macro, after_setup', 1, true), order)
T.ok('init_gear_sets after user_setup: the sets, then after_sets', order:find('after_setup, sets sets/tst_sets.lua, after_sets', 1, true), order)
T.ok('then the common configs, configs(), the job\'s files, after_load',
    order:find('after_sets, configs, cancel, lockstyle TST, file TST_PRECAST', 1, true) and order:find('after_load$'), order)
check('the common configs', _G.RECAST_CONFIG and _G.TSTTPConfig and _G.TSTTPConfig.tp, true)
check('the keybind module', _G.TSTKeybinds ~= nil, true)
trace = {}
job_update()
check('job_update: the step, then the HUD', table.concat(trace, ', '), 'update, hud update')
trace = {}
job_sub_job_change('NIN')
local saved_player = player
player = nil
job_sub_job_change('DNC')
player = saved_player
check('job_sub_job_change: the game\'s job, the entry\'s without player', table.concat(trace, ', '),
    'change WAR/NIN, change TST/DNC')
trace = {}
file_unload('next.lua')
check('file_unload: the job\'s releases first, then the job change cancelled and the keys', table.concat(trace, ', '),
    'unload next.lua, cancel, unbind')
trace = {}
_G.TSTKeybinds = nil
file_unload(nil)
check('file_unload without keys', table.concat(trace, ', '), 'unload, cancel')

T.done()
