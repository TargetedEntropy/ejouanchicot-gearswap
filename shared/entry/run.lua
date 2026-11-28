---============================================================================
--- FFXI GearSwap Configuration - Rune Fencer (RUN) - Modular Architecture
---============================================================================
--- Main coordinator for Rune Fencer job configuration.
--- Delegates all specialized logic to dedicated modules for maximum maintainability.
---
--- Features:
---   • Modular architecture (hook modules + 4 logic modules)
---   • Tank gear automation (HybridMode PDT/MDT)
---   • Rune selection from state.RuneMode (rune_manager)
---   • Blue Magic AOE spell rotation (RUN/BLU, aoe_manager)
---   • Cure set selection by target (cure_set_builder)
---   • JobChangeManager integration (anti-collision)
---   • UI + Keybind system
---
--- Architecture:
---   EntryKit.job >> load_job >> Hooks + 4 Logic Modules
---
--- Modules:
---   • Hooks: PRECAST, MIDCAST, AFTERCAST, IDLE, ENGAGED, STATUS, BUFFS,
---               COMMANDS
---   • 4 Logic: aoe_manager, cure_set_builder, rune_manager, set_builder
---
--- @file    shared/entry/run.lua
--- @author  ejouanchicot
--- @version 1.0.0
--- @date    Created: 2025-11-02
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with RUN's Blue Magic configuration and its keybinds bound 0.5 s later. RUN_TP_CONFIG.lua
-- also sets _G.RUNTPConfig itself.
local CharPaths = require('shared/utils/core/char_paths')

require('shared/utils/core/entry_kit').job('RUN', {
    -- aoe_manager reads _G.BluMagicConfig when it loads (RUN_COMMANDS.lua, included after this step)
    configs = function()
        _G.BluMagicConfig = require(CharPaths.module('job', 'RUN_BLU_MAGIC', 'RUN'))
    end,
    keybinds_delay = 0.5,
})
