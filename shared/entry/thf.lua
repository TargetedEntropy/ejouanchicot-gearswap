---============================================================================
--- FFXI GearSwap Configuration - Thief (THF) - Modular Architecture
---============================================================================
--- Advanced Thief job configuration built on modular architecture principles.
--- This file serves as the main coordinator, delegating all specialized logic
--- to dedicated modules for maximum maintainability and scalability.
---
--- @file shared/entry/thf.lua
--- @author ejouanchicot
--- @version 1.0.0 - Initial Release (Architecture v2.4)
--- @date Created: 2025-10-06
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Key Features:
---   - Modular architecture with Hooks vs Logic separation
---   - Comprehensive equipment set organization
---   - Clean separation of concerns
---
--- Architecture Overview:
---   EntryKit.job >> EntryKit.load_job_files >> Hooks >> Logic Modules
---
--- Module Organization:
---   ├── functions/thf_functions.lua    [THF's own start]
---   ├── functions/logic/               [Business Logic]
---   ├── <Character>/thf/sets/thf_sets.lua [Equipment Sets]
---   └── functions/THF_*.lua           [Hooks Modules]
---
--- Hooks Modules:
---   THF_PRECAST | THF_MIDCAST | THF_AFTERCAST | THF_STATUS | THF_BUFFS
---   THF_IDLE | THF_ENGAGED | THF_COMMANDS
---
--- Logic Modules:
---   logic/treasure_hunter.lua  - TH tracking and management
---   logic/sa_ta_manager.lua    - Sneak Attack/Trick Attack logic
---   logic/set_builder.lua      - Set construction (idle/engaged)
---   logic/smartbuff_manager.lua - Buff automation
---   logic/range_lock.lua       - Range/ammo slot lock (RangeLock state)
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with THF's range / ammo lock
local function range_lock()
    local ok, RangeLock = pcall(require, 'shared/jobs/thf/functions/logic/range_lock')
    return ok and RangeLock or nil
end

require('shared/utils/core/entry_kit').job('THF', {
    -- A subjob change re-runs user_setup in the same sandbox: keep RangeLock On while the range/ammo lock is still
    -- in place.
    after_states = function()
        local RangeLock = range_lock()
        if RangeLock then RangeLock.sync_state() end
    end,
    -- Release the range/ammo lock: GearSwap keeps slot locks across job files while RangeLock starts Off in the
    -- next one. First in file_unload (EntryKit.job runs unload before anything else): GearSwap wraps the whole of
    -- file_unload in a single pcall (engine flow.lua:339-348), so an error after it would leak the slot lock into
    -- the next job.
    unload = function()
        local RangeLock = range_lock()
        if RangeLock then RangeLock.release() end
    end,
})
