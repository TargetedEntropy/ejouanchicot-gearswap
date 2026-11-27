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
---   Main File (this) >> thf_functions.lua >> Hooks >> Logic Modules
---
--- Module Organization:
---   ├── functions/thf_functions.lua    [Facade Loader]
---   ├── functions/logic/               [Business Logic]
---   ├── <Character>/thf/sets/thf_sets.lua [Equipment Sets]
---   └── functions/THF_*.lua           [Hooks Modules]
---
--- Hooks Modules:
---   THF_PRECAST | THF_MIDCAST | THF_AFTERCAST | THF_STATUS | THF_BUFFS
---   THF_IDLE | THF_ENGAGED | THF_MACROBOOK | THF_COMMANDS | THF_MOVEMENT
---   THF_LOCKSTYLE
---
--- Logic Modules:
---   logic/treasure_hunter.lua  - TH tracking and management
---   logic/sa_ta_manager.lua    - Sneak Attack/Trick Attack logic
---   logic/set_builder.lua      - Set construction (idle/engaged)
---   logic/smartbuff_manager.lua - Buff automation
---   logic/range_lock.lua       - Range/ammo slot lock (RangeLock state)
---============================================================================

---============================================================================
-- INITIALIZATION
---============================================================================

-- Load lockstyle timing configuration
-- Where the character's files are (_common/, <job>/, saved/; older config/ and sets/)
local CharPaths = require('shared/utils/core/char_paths')
-- The hooks every entry shares (job_update, subjob change, unload, keybind error)
local EntryKit = require('shared/utils/core/entry_kit')

-- the lockstyle delays, the region colours, the HUD settings (EntryKit.load_configs)
local LockstyleConfig, UIConfig = EntryKit.load_configs('THF')

--- GearSwap entry hook: loads Mote-Include, the shared systems and the THF modules.
--- Called by GearSwap each time this job file is loaded.
--- @return void
function get_sets()
    -- PERFORMANCE PROFILING (enable with: //gs c perf start)
    local Profiler = require('shared/utils/debug/performance_profiler')
    Profiler.start('get_sets')

    mote_include_version = 2
    include('Mote-Include.lua')
    Profiler.mark('After Mote-Include')
    -- the shared systems, the data, the spell / ability / weaponskill messages
    EntryKit.after_mote(Profiler)

    _G.LockstyleConfig = LockstyleConfig
    _G.RECAST_CONFIG = require(CharPaths.module('common', 'RECAST_CONFIG'))

    -- THF-specific configs
    _G.THFTPConfig = require(CharPaths.module('job', 'THF_TP_CONFIG', 'THF'))

    -- what the last job scheduled is cancelled, the facade loaded, its lockstyle cancel registered
    EntryKit.load_facade('THF', Profiler)

    -- Initial macrobook/lockstyle are triggered from user_setup();
    -- subjob changes go through JobChangeManager (job_sub_job_change).

    Profiler.finish()
end

---============================================================================
-- JOB CHANGE HANDLING
---============================================================================

--- Handle sub job change events (called by Mote-Include)
--- Coordinates lockstyle, macros, keybinds, and UI reload via JobChangeManager
--- @param newSubjob string New subjob
--- @param oldSubjob string Old subjob
--- @return void
function job_sub_job_change(newSubjob, oldSubjob)
    EntryKit.sub_job_change('THF', newSubjob)
end

---============================================================================
-- SETUP FUNCTIONS
---============================================================================

--- Configure states, RangeLock sync, keybinds, UI and the initial macrobook/lockstyle.
--- Called by Mote-Include from init_include() (inside include('Mote-Include.lua'),
--- before init_gear_sets) and again on every subjob change, before job_sub_job_change().
--- @return void
function user_setup()
    -- ==========================================================================
    -- STATE DEFINITIONS (Loaded from THF_STATES.lua)
    -- ==========================================================================
    local THFStates = require(CharPaths.module('job', 'THF_STATES', 'THF'))
    THFStates.configure()

    -- A subjob change re-runs this in the same sandbox: keep RangeLock On
    -- while the range/ammo lock is still in place.
    local rl_ok, RangeLock = pcall(require, 'shared/jobs/thf/functions/logic/range_lock')
    if rl_ok and RangeLock then
        RangeLock.sync_state()
    end

    -- ==========================================================================
    -- KEYBIND LOADING (Always executed after reload)
    -- ==========================================================================
    local success, keybinds = pcall(require, CharPaths.module('job', 'THF_KEYBINDS', 'THF'))
    if success and keybinds then
        THFKeybinds = keybinds
        THFKeybinds.bind_all()
    else
        EntryKit.keybind_error('THF', keybinds)
    end

    -- ==========================================================================
    -- UI INITIALIZATION (Always executed after reload)
    -- ==========================================================================
    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        local init_delay = (_G.UIConfig and _G.UIConfig.init_delay) or 5.0
        KeybindUI.smart_init("THF", init_delay)
    end

    -- ==========================================================================
    -- JOB CHANGE MANAGER INITIALIZATION (Always executed after reload)
    -- ==========================================================================
    local jcm_success, JobChangeManager = pcall(require, 'shared/utils/core/job_change_manager')
    if jcm_success and JobChangeManager then
        -- Initialize with current job state
        JobChangeManager.initialize()

        EntryKit.macro_and_lockstyle(LockstyleConfig.initial_load_delay)
    end

    -- ==========================================================================
    -- DUALBOX IPC (covers main job change - job_sub_job_change is subjob-only)
    -- The require() triggers dualbox_manager auto-init which schedules the
    -- correct IPC call once per gs reload (request_alt_job for MAIN role,
    -- send_job_update for ALT role). Do NOT call them explicitly here.
    -- ==========================================================================
    pcall(require, 'shared/utils/dualbox/dualbox_manager')
end

---============================================================================
--- STATE UPDATE HOOK
---============================================================================

--- Called by Mote-Include after state changes
--- Updates the UI to reflect current state values
--- @param cmdParams table Parameters passed to Mote's handle_update
--- @param eventArgs table Mote event arguments (unused)
--- @return void
function job_update(cmdParams, eventArgs)
    EntryKit.update_hud('THF')
end

--- Load the THF equipment sets.
--- Called by Mote-Include at the end of init_include(), after user_setup().
--- @return void
function init_gear_sets()
    include(CharPaths.relative('sets', 'thf_sets.lua', 'THF'))
end

--- Called by GearSwap when this job file is unloaded (job change, reload).
--- Releases the range/ammo lock first, then cancels pending job-change
--- operations and unbinds the job keys.
--- @return void
function file_unload()
    -- Release the range/ammo lock: GearSwap keeps slot locks across job files
    -- while RangeLock starts Off in the next one.
    -- First, before anything else in here can throw: GearSwap wraps the whole
    -- of file_unload in a single pcall (engine flow.lua:339-348), so an error
    -- in the cleanup below would skip this and leak the slot lock into the
    -- next job, which has no way to know it exists.
    local rl_ok, RangeLock = pcall(require, 'shared/jobs/thf/functions/logic/range_lock')
    if rl_ok and RangeLock then
        RangeLock.release()
    end

    EntryKit.unload(THFKeybinds)
end
