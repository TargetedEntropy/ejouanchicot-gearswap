---============================================================================
--- FFXI GearSwap Configuration - Monk (MNK) - Modular Architecture
---============================================================================
--- Loader for the Monk job: Mote-Include, the shared systems, the MNK
--- hook modules and this character's configs and sets.
---
--- @file shared/entry/mnk.lua
--- @author ejouanchicot
--- @version 1.0
--- @date Created: 2026-09-29
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Architecture:
---   Main File (this) >> mnk_functions.lua >> Hooks >> Logic Modules
---
--- Hooks Modules:
---   MNK_PRECAST | MNK_MIDCAST | MNK_AFTERCAST | MNK_STATUS | MNK_BUFFS
---   MNK_IDLE | MNK_ENGAGED | MNK_COMMANDS
---
--- Logic Modules:
---   logic/buff_layers.lua  - Impetus / Footwork / Hundred Fists /
---                            Counterstance layers (engaged, weaponskills)
---   logic/set_builder.lua  - Idle / engaged sets
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
local LockstyleConfig, UIConfig = EntryKit.load_configs('MNK')

--- GearSwap entry hook: loads Mote-Include, the shared systems and the MNK modules.
--- Called by GearSwap each time this job file is loaded.
--- @return void
function get_sets()
    local Profiler = require('shared/utils/debug/performance_profiler')
    Profiler.start('get_sets')

    mote_include_version = 2
    include('Mote-Include.lua')
    Profiler.mark('After Mote-Include')
    -- the shared systems, the data, the spell / ability / weaponskill messages
    EntryKit.after_mote(Profiler)

    Profiler.mark('After message hooks')

    _G.LockstyleConfig = LockstyleConfig
    _G.RECAST_CONFIG = require(CharPaths.module('common', 'RECAST_CONFIG'))

    -- MNK-specific configs
    _G.MNKTPConfig = require(CharPaths.module('job', 'MNK_TP_CONFIG', 'MNK'))

    -- what the last job scheduled is cancelled, the facade loaded, its lockstyle cancel registered
    EntryKit.load_facade('MNK', Profiler)

    Profiler.finish()
end

---============================================================================
-- JOB CHANGE HANDLING
---============================================================================

--- Handle sub job change events (called by Mote-Include)
--- @param newSubjob string New subjob
--- @param oldSubjob string Old subjob
--- @return void
function job_sub_job_change(newSubjob, oldSubjob)
    EntryKit.sub_job_change('MNK', newSubjob)
end

---============================================================================
-- SETUP FUNCTIONS
---============================================================================

--- Configure states, keybinds, UI and the initial macrobook/lockstyle.
--- Called by Mote-Include from init_include() (inside include('Mote-Include.lua'),
--- before init_gear_sets) and again on every subjob change.
--- @return void
function user_setup()
    local MNKStates = require(CharPaths.module('job', 'MNK_STATES', 'MNK'))
    MNKStates.configure()

    local success, keybinds = pcall(require, CharPaths.module('job', 'MNK_KEYBINDS', 'MNK'))
    if success and keybinds then
        MNKKeybinds = keybinds
        MNKKeybinds.bind_all()
    else
        EntryKit.keybind_error('MNK', keybinds)
    end

    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        local init_delay = (_G.UIConfig and _G.UIConfig.init_delay) or 5.0
        KeybindUI.smart_init("MNK", init_delay)
    end

    local jcm_success, JobChangeManager = pcall(require, 'shared/utils/core/job_change_manager')
    if jcm_success and JobChangeManager then
        JobChangeManager.initialize()
        EntryKit.macro_and_lockstyle(LockstyleConfig.initial_load_delay)
    end

    -- DUALBOX IPC: the require() triggers dualbox_manager auto-init (once per gs reload)
    pcall(require, 'shared/utils/dualbox/dualbox_manager')
end

---============================================================================
--- STATE UPDATE HOOK
---============================================================================

--- Called by Mote-Include after state changes: refresh the HUD.
--- @param cmdParams table Parameters passed to Mote's handle_update
--- @param eventArgs table Mote event arguments (unused)
--- @return void
function job_update(cmdParams, eventArgs)
    EntryKit.update_hud('MNK')
end

--- Load the MNK equipment sets.
--- Called by Mote-Include at the end of init_include(), after user_setup().
--- @return void
function init_gear_sets()
    include(CharPaths.relative('sets', 'mnk_sets.lua', 'MNK'))
end

--- Called by GearSwap when this job file is unloaded (job change, reload).
--- @return void
function file_unload()
    EntryKit.unload(MNKKeybinds)
end
