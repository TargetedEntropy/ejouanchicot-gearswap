---============================================================================
--- FFXI GearSwap Configuration - Red Mage (RDM) - Modular Architecture
---============================================================================
--- Advanced Red Mage job configuration built on modular architecture principles.
--- This file serves as the main coordinator, delegating all specialized logic
--- to dedicated modules for maximum maintainability and scalability.
---
--- @file shared/entry/rdm.lua
--- @author ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date Created: 2025-10-12
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Key Features:
---   - Modular architecture with specialized function modules
---   - Fast Cast optimization (cap 80%)
---   - Convert HP/MP management
---   - Chainspell burst mode support
---   - Enspell weapon enhancement
---   - Dualwield support (NIN subjob)
---   - Hybrid white/black magic
---   - Light/Dark elemental spell management
---
--- Architecture Overview:
---   EntryKit.job >> load_job >> Specialized Modules
---
--- Module Organization:
---   ├── <Character>/rdm/sets/rdm_sets.lua [Equipment Sets]
---   └── functions/RDM_*.lua            [Specialized Modules]
---
--- Specialized Modules:
---   RDM_PRECAST | RDM_MIDCAST | RDM_AFTERCAST | RDM_STATUS | RDM_BUFFS
---   RDM_IDLE | RDM_ENGAGED | RDM_COMMANDS
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with RDM's Saboteur configuration and Cure Auto-Tier mode. RDM_TP_CONFIG.lua also sets
-- _G.RDMTPConfig itself; RDMStates.configure() creates the Storm state when the subjob is SCH (configure_storm), on
-- every load and every subjob change, so job_sub_job_change has no Storm work.
local CharPaths = require('shared/utils/core/char_paths')

require('shared/utils/core/entry_kit').job('RDM', {
    configs = function()
        local ok, RDMSaboteurConfig = pcall(require, CharPaths.module('job', 'RDM_SABOTEUR_CONFIG', 'RDM'))
        _G.RDMSaboteurConfig = (ok and RDMSaboteurConfig) or {auto_trigger_spells = {}, wait_time = 2}
    end,
    -- Cure Auto-Tier mode (state.CureAutoTier), when the character has a RDM_CURE_CONFIG.lua (<Char>/rdm/combat/):
    -- made in shared/utils/whm/cure_manager.lua setup_state, before the keybinds so the HUD shows it
    after_states = function()
        local ok, CureManager = pcall(require, 'shared/utils/whm/cure_manager')
        if ok and CureManager then CureManager.setup_state() end
    end,
})
