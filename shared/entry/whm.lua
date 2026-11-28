---============================================================================
--- FFXI GearSwap Configuration - White Mage (WHM) - Modular Architecture
---============================================================================
--- Main coordinator for White Mage job configuration.
--- Delegates all specialized logic to dedicated modules for maximum maintainability.
---
--- Features:
---   • Modular architecture (hook modules + 1 logic module)
---   • Healer-focused gear automation (Cure optimization)
---   • Afflatus Solace/Misery support
---   • Enhancing magic duration optimization
---   • Divine/Enfeebling magic support
---   • JobChangeManager integration (anti-collision)
---   • UI + Keybind system
---
--- Architecture:
---   EntryKit.job >> load_job >> Hooks + Logic Module
---
--- Modules:
---   • Hooks: PRECAST, MIDCAST, AFTERCAST, IDLE, ENGAGED, STATUS, BUFFS,
---               COMMANDS
---   • Logic: set_builder
---   • Shared: shared/utils/whm/cure_manager.lua (Cure tier, WHM_CURE_CONFIG)
---
--- @file    shared/entry/whm.lua
--- @author  ejouanchicot
--- @version 1.0.0
--- @date    Created: 2025-10-21
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with WHM's Cure tier start and its melee lock release
local CharPaths = require('shared/utils/core/char_paths')

require('shared/utils/core/entry_kit').job('WHM', {
    -- The Cure tier choice starts as WHM_CURE_CONFIG.lua says (auto_tier_enabled = false: the Cure Auto-Tier mode
    -- starts Off). Its key turns it on and off afterwards, until the next load.
    after_states = function()
        local ok, cure_config = CharPaths.load('job', 'WHM_CURE_CONFIG', 'WHM')
        if ok and type(cure_config) == 'table' and cure_config.auto_tier_enabled == false and state.CureAutoTier then
            state.CureAutoTier:set('Off')
        end
    end,
    -- disable() lives in GearSwap's own table, which survives the reload, while OffenseMode comes back at its
    -- default: release its lock here. Read from windower._whm_melee_lock (set by WHM_COMMANDS), not from the mode:
    -- on a subjob change Mote's user_setup() has already reset OffenseMode to None. Not during a craft session,
    -- whose lock CraftManager owns. The Combat Mode lock is freed by the next job (shared/utils/core/combat_mode.lua).
    unload = function()
        local craft_ok, crafting = pcall(function()
            return require('shared/utils/craft/craft_manager').is_active()
        end)
        if not (craft_ok and crafting) then
            if windower._whm_melee_lock or (state and state.OffenseMode and state.OffenseMode.value == 'Melee ON') then
                enable('main', 'sub', 'range')
                windower._whm_melee_lock = nil
                pcall(function() require('shared/utils/core/combat_mode').release('whm_melee') end)
            end
        end
    end,
})
