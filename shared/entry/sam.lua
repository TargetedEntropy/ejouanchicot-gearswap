---============================================================================
--- FFXI GearSwap Configuration - Samurai (SAM) - Modular Architecture
---============================================================================
--- Main coordinator for Samurai job configuration. Loads Mote-Include, the
--- shared systems and the SAM modules (EntryKit.load_job_files).
---
--- @file shared/entry/sam.lua
--- @author ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date Created: 2025-10-21
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---============================================================================

-- Load configs
-- Where the character's files are (_common/, <job>/, saved/; older config/ and sets/)
local CharPaths = require('shared/utils/core/char_paths')
-- The hooks every entry shares (job_update, subjob change, unload, keybind error)
local EntryKit = require('shared/utils/core/entry_kit')

-- the lockstyle delays, the region colours, the HUD settings (EntryKit.load_configs)
local LockstyleConfig, UIConfig = EntryKit.load_configs('SAM')

--- GearSwap entry hook: loads Mote-Include, the shared systems and the SAM modules.
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

    -- ============================================
    -- LOAD CONFIGS INTO GLOBAL NAMESPACE
    -- ============================================
    _G.LockstyleConfig = LockstyleConfig
    _G.UIConfig = UIConfig
    _G.RECAST_CONFIG = require(CharPaths.module('common', 'RECAST_CONFIG'))

    -- SAM-specific configs
    _G.SAMTPConfig = require(CharPaths.module('job', 'SAM_TP_CONFIG', 'SAM'))

    -- Cancel any pending operations from previous job
    local jcm_success, JobChangeManager = pcall(require, 'shared/utils/core/job_change_manager')
    if jcm_success and JobChangeManager then
        JobChangeManager.cancel_all()
    end

    -- the job's hook files, lockstyle and macro book (EntryKit.load_job_files)
    EntryKit.load_job_files('SAM')
    Profiler.mark('After sam files')

    -- Register SAM lockstyle cancel function
    if jcm_success and JobChangeManager and cancel_sam_lockstyle_operations then
        JobChangeManager.register_lockstyle_cancel('SAM', cancel_sam_lockstyle_operations)
    end

    Profiler.finish()
end

--- Handle sub job change events (called by Mote-Include after user_setup())
--- Hands the reload to JobChangeManager.
--- @param newSubjob string New subjob
--- @param oldSubjob string Old subjob
--- @return void
function job_sub_job_change(newSubjob, oldSubjob)
    EntryKit.sub_job_change('SAM', newSubjob)
end

--- Configure states, keybinds, UI and the initial macrobook/lockstyle.
--- Called by Mote-Include from init_include() (inside include('Mote-Include.lua'),
--- before init_gear_sets) and again on every subjob change, before job_sub_job_change().
--- @return void
function user_setup()
    -- STATE DEFINITIONS (Loaded from SAM_STATES.lua)
    -- All state configurations (HybridMode, MainWeapon, Buff tracking) managed by SAMStates module
    local SAMStates = require(CharPaths.module('job', 'SAM_STATES', 'SAM'))
    SAMStates.configure()

    -- ==========================================================================
    -- KEYBIND LOADING (Always executed after reload)
    -- ==========================================================================
    local success, keybinds = pcall(require, CharPaths.module('job', 'SAM_KEYBINDS', 'SAM'))
    if success and keybinds then
        SAMKeybinds = keybinds
        SAMKeybinds.bind_all()
    else
        EntryKit.keybind_error('SAM', keybinds)
    end

    -- ==========================================================================
    -- UI INITIALIZATION (Always executed after reload)
    -- ==========================================================================
    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        KeybindUI.smart_init('SAM', UIConfig.init_delay)
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
    EntryKit.update_hud('SAM')
end

--- Load the SAM equipment sets.
--- Called by Mote-Include at the end of init_include(), after user_setup().
--- @return void
function init_gear_sets()
    include(CharPaths.relative('sets', 'sam_sets.lua', 'SAM'))
end

--- Called by GearSwap when this job file is unloaded (job change, reload).
--- Cancels pending job-change operations and unbinds the job keys.
--- @return void
function file_unload()
    EntryKit.unload(SAMKeybinds)
end
