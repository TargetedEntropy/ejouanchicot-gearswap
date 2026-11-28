---============================================================================
--- FFXI GearSwap Configuration - Corsair (COR) - Modular Architecture
---============================================================================
--- Advanced Corsair job configuration built on modular architecture principles.
--- This file serves as the main coordinator, delegating all specialized logic
--- to dedicated modules for maximum maintainability and scalability.
---
--- @file shared/entry/cor.lua
--- @author ejouanchicot
--- @version 1.2.0
--- @date Created: 2025-10-07
--- @date Updated: 2025-10-09 - Party job detection via packet parsing
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+, packets library, resources library
---
--- Key Features:
---   - Modular architecture with specialized function modules
---   - Phantom Roll management with Lucky/Safe Number tracking
---   - Automatic party job detection via packet parsing (0xDD/0xDF) for accurate job bonuses
---   - Quick Draw elemental shot system
---   - Ranged and Melee combat optimization
---   - Comprehensive equipment set organization
---
--- Architecture Overview:
---   EntryKit.job >> EntryKit.load_job_files >> Specialized Modules
---
--- Module Organization:
---   ├── <Character>/cor/sets/cor_sets.lua [Equipment Sets]
---   └── functions/COR_*.lua           [Specialized Modules]
---
--- Specialized Modules:
---   COR_PRECAST | COR_MIDCAST | COR_AFTERCAST | COR_STATUS | COR_BUFFS
---   COR_IDLE | COR_ENGAGED | COR_COMMANDS
---   COR_MOVEMENT
---
--- Packet Event Handlers:
---   - Action packets (category 6): Roll value detection for initial rolls and Double-Up
---   - Incoming chunk (0xDD/0xDF): Party member job detection for automatic job bonuses
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with COR's roll tracking and the rolltracker addon it replaces
local function roll_tracker()
    local ok, RollTracker = pcall(require, 'shared/jobs/cor/functions/logic/roll_tracker')
    return ok and RollTracker or nil
end

--- PartyTracker and roll detection, from get_sets(): every dependency it needs exists by then.
local function init_party_tracking()
    local pt_ok, PartyTracker = pcall(require, 'shared/jobs/cor/functions/logic/party_tracker')
    if not pt_ok then PartyTracker = nil end
    local mf_ok, MF = pcall(require, 'shared/utils/messages/message_formatter')
    if not mf_ok then MF = nil end
    if not PartyTracker then
        if MF then
            MF.show_error('[COR] PartyTracker failed to load - no roll detection')
        end
        return
    end
    local init_ok, init_err = pcall(PartyTracker.init)
    if init_ok then
        return
    end
    if MF then
        MF.show_error('[COR] PartyTracker.init() failed: ' .. tostring(init_err))
    end
    -- init() unregisters the previous handler before it rebuilds anything, so a
    -- throw partway through leaves NO roll detection at all. The party job cache
    -- is a nicety - the roll report is the point - so re-arm the listener alone.
    local listener_ok, listener_err = pcall(PartyTracker.init_roll_listener)
    if not listener_ok and MF then
        MF.show_error('[COR] Roll detection unavailable: ' .. tostring(listener_err))
    end
end

--- The rolltracker addon comes back once the game is off COR.
local function release_rolltracker(next_file)
    if not windower._cor_rolltracker_off then return end
    local function reload_rolltracker()
        windower._cor_rolltracker_off = nil
        windower.send_command('lua load rolltracker')
    end
    if next_file == nil then
        -- GearSwap itself is unloading: no later check would ever run
        return reload_rolltracker()
    end
    -- GearSwap still reports the old job here, and the next file may be COR
    -- again (subjob change, //gs reload): ask the game 2 s later. Only
    -- windower.* in this coroutine: it runs after the sandbox is gone.
    coroutine.schedule(function()
        local me = windower.ffxi.get_player()
        if me and me.main_job == 'COR' then return end
        reload_rolltracker()
    end, 2)
end

require('shared/utils/core/entry_kit').job('COR', {
    -- A clean slate for roll tracking (COR loaded again after another job). Old events need no cleanup: GearSwap
    -- unregisters every event of the previous job file at load (refresh.lua), and _G is a new environment.
    before_mote = function()
        _G.cor_pending_roll_value = nil
        local RollTracker = roll_tracker()
        if RollTracker and RollTracker.cleanup then RollTracker.cleanup() end
    end,
    -- The rolltracker addon would conflict with the integrated roll tracker: unloaded here, loaded again by
    -- file_unload once the game is off COR (both skipped with rolltracker = false in
    -- _common/tools/ADDONS_CONFIG.lua). The flag lives on `windower`, which outlives the job sandbox: a subjob
    -- change or //gs reload of COR sends neither the load nor the unload again (same pattern as BLU,
    -- shared/jobs/blu/functions/logic/azure_sets.lua).
    configs = function()
        if not windower._cor_rolltracker_off then
            windower._cor_rolltracker_off = require('shared/utils/core/job_addons').run('unload', 'rolltracker')
        end
    end,
    after_load = init_party_tracking,
    unload = function(next_file)
        -- the roll detection handler (PartyTracker.init_roll_listener, from get_sets)
        pcall(function() require('shared/utils/core/action_listener').off('cor_roll') end)
        -- every roll state and global
        local RollTracker = roll_tracker()
        if RollTracker and RollTracker.cleanup then RollTracker.cleanup() end
        -- PartyTracker's event handlers and state
        local pt_ok, PartyTracker = pcall(require, 'shared/jobs/cor/functions/logic/party_tracker')
        if pt_ok and PartyTracker and PartyTracker.cleanup then PartyTracker.cleanup() end
        release_rolltracker(next_file)
    end,
})
