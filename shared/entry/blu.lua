---============================================================================
--- FFXI GearSwap Configuration - Blue Mage (BLU) - Modular Architecture
---============================================================================
--- Loader for the Blue Mage job: Mote-Include, the shared systems, the BLU
--- hook modules and this character's configs and sets.
---
--- @file shared/entry/blu.lua
--- @author ejouanchicot
--- @version 1.0
--- @date Created: 2026-09-26
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Architecture:
---   Main File (this) >> EntryKit.load_job_files >> Hooks >> Logic Modules
---
--- Hooks Modules:
---   BLU_PRECAST | BLU_MIDCAST | BLU_AFTERCAST | BLU_STATUS | BLU_BUFFS
---   BLU_IDLE | BLU_ENGAGED | BLU_COMMANDS
---
--- Logic Modules:
---   logic/spell_map.lua        - Blue Magic spell -> gear category
---   logic/set_builder.lua      - Idle / engaged sets, single wield
---   logic/unbridled.lua        - Unbridled Learning first (option)
---   logic/expiacion_guard.lua  - Expiacion held for Aftermath Lv.3 (option)
---   logic/azure_sets.lua       - AzureSets addon while on BLU
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
local LockstyleConfig, UIConfig = EntryKit.load_configs('BLU')

--- GearSwap entry hook: loads Mote-Include, the shared systems and the BLU modules.
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

    -- BLU-specific configs
    _G.BLUTPConfig = require(CharPaths.module('job', 'BLU_TP_CONFIG', 'BLU'))

    -- what the last job scheduled is cancelled, the job's files loaded (EntryKit.load_job_files), its lockstyle
    -- cancel registered
    EntryKit.load_job('BLU', Profiler)

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
    EntryKit.sub_job_change('BLU', newSubjob)
end

---============================================================================
-- SETUP FUNCTIONS
---============================================================================

--- Configure states, keybinds, UI, the initial macrobook/lockstyle and AzureSets.
--- Called by Mote-Include from init_include() (inside include('Mote-Include.lua'),
--- before init_gear_sets) and again on every subjob change.
--- @return void
function user_setup()
    local BLUStates = require(CharPaths.module('job', 'BLU_STATES', 'BLU'))
    BLUStates.configure()

    local success, keybinds = pcall(require, CharPaths.module('job', 'BLU_KEYBINDS', 'BLU'))
    if success and keybinds then
        BLUKeybinds = keybinds
        BLUKeybinds.bind_all()
    else
        EntryKit.keybind_error('BLU', keybinds)
    end

    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        local init_delay = (_G.UIConfig and _G.UIConfig.init_delay) or 5.0
        KeybindUI.smart_init("BLU", init_delay)
    end

    local jcm_success, JobChangeManager = pcall(require, 'shared/utils/core/job_change_manager')
    if jcm_success and JobChangeManager then
        JobChangeManager.initialize()
        EntryKit.macro_and_lockstyle(LockstyleConfig.initial_load_delay)
    end

    -- AzureSets (Blue Magic spell lists) while on BLU
    local az_ok, AzureSets = pcall(require, 'shared/jobs/blu/functions/logic/azure_sets')
    if az_ok and AzureSets then
        AzureSets.load()
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
    EntryKit.update_hud('BLU')
end

--- Load the BLU equipment sets.
--- Called by Mote-Include at the end of init_include(), after user_setup().
--- @return void
function init_gear_sets()
    include(CharPaths.relative('sets', 'blu_sets.lua', 'BLU'))
end

--- Called by GearSwap when this job file is unloaded (job change, reload).
--- @return void
function file_unload()
    -- First: GearSwap runs file_unload under one pcall (engine refresh.lua
    -- load_user_files), so an error further down would skip what follows it.
    local az_ok, AzureSets = pcall(require, 'shared/jobs/blu/functions/logic/azure_sets')
    if az_ok and AzureSets then
        AzureSets.unload()
    end

    EntryKit.unload(BLUKeybinds)
end
