---============================================================================
--- Test of the hooks every entry shares (shared/utils/core/entry_kit.lua)
---============================================================================
--- The first macro book and lockstyle come even when the keybinds did not
--- load (the job's files define them only after user_setup), and a newer load
--- drops them, and so does the old sandbox's user_setup() on a subjob change;
--- unload cancels then unbinds; a subjob change goes to
--- JobChangeManager with the job of the game.
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

-- 3. unload: cancel first, then the keys
calls = {}
EntryKit.unload({unbind_all = function() calls[#calls + 1] = 'unbind' end})
check('unload cancels', calls[1], 'cancel')
check('unload unbinds', calls[2], 'unbind')
EntryKit.unload(nil)
check('unload without keys', calls[3], 'cancel')

-- 4. subjob change: the game's main job, the entry's when player is not readable
calls = {}
EntryKit.sub_job_change('WAR', 'DNC')
player = nil
EntryKit.sub_job_change('WAR', 'NIN')
check('subjob change with the game job', calls[1], 'change WAR/DNC')
check('subjob change without player', calls[2], 'change WAR/NIN')

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

T.done()
