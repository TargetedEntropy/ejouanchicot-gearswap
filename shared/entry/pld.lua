---============================================================================
--- FFXI GearSwap Configuration - Paladin (PLD) - Modular Architecture
---============================================================================
--- Main coordinator for Paladin job configuration.
--- Delegates all specialized logic to dedicated modules for maximum maintainability.
---
--- Features:
---   • Modular architecture (hook modules + 5 logic modules)
---   • Tank-focused gear automation (PDT/MDT modes)
---   • Blue Magic AOE spell rotation (PLD/BLU)
---   • Rune management (RUN subjob)
---   • Cure set automation with potency optimization
---   • AOE spell management
---   • JobChangeManager integration (anti-collision)
---   • UI + Keybind system
---
--- Architecture:
---   EntryKit.job >> load_job >> Hooks + 5 Logic Modules
---
--- Modules:
---   • Hooks: PRECAST, MIDCAST, AFTERCAST, IDLE, ENGAGED, STATUS, BUFFS,
---               COMMANDS
---   • 5 Logic: aoe_manager, cure_set_builder, enmity_override, rune_manager, set_builder
---
--- @file    shared/entry/pld.lua
--- @author  ejouanchicot
--- @version 1.0.0
--- @date    Created: 2025-10-03
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with PLD's Blue Magic configuration, weaponskill slots and Ampulla lock. PLD_TP_CONFIG.lua
-- also sets _G.PLDTPConfig itself.
local CharPaths = require('shared/utils/core/char_paths')

local function ampulla_lock()
    local ok, AmpullaLock = pcall(require, 'shared/utils/equipment/ampulla_lock')
    return ok and AmpullaLock or nil
end

local function rebuild_ws_slots()
    if _G.pld_rebuild_ws_slots then
        _G.pld_rebuild_ws_slots()
    end
end

require('shared/utils/core/entry_kit').job('PLD', {
    -- before user_setup: PLDStates builds state.WS1/WS2 from it
    before_mote = function()
        _G.PLDWSConfig = CharPaths.optional('job', 'PLD_WS_CONFIG', 'PLD')
    end,
    configs = function()
        _G.BluMagicConfig = require(CharPaths.module('job', 'PLD_BLU_MAGIC', 'PLD'))
    end,
    -- Refresh the slots now set_builder can be loaded: PLDStates created them during user_setup (the HUD needs them
    -- by then) with whatever weapon it could resolve that early.
    after_load = rebuild_ws_slots,
    after_states = function()
        -- Fill state.WS1/WS2 for the weapon in hand. Reached on a subjob change, which re-runs user_setup() in a
        -- sandbox where the job modules are already loaded; on a cold load the function does not exist yet and
        -- get_sets() does it instead (after_load).
        rebuild_ws_slots()
        -- configure() has just put HybridMode back to its default, so any ammo lock still held by the sandbox
        -- belongs to a stance that is no longer selected. GearSwap slot locks outlive the job file; nothing else
        -- would ever give the slot back.
        local AmpullaLock = ampulla_lock()
        if AmpullaLock then AmpullaLock.apply(state.HybridMode and state.HybridMode.value) end
    end,
    -- Give the ammo slot back before the next job file loads: a GearSwap slot lock survives a job change, and
    -- nothing on the other side knows it. First in file_unload: GearSwap wraps the whole of it in a single pcall
    -- (engine flow.lua:339-348), so an error after it would leak the slot lock into the next job.
    unload = function()
        local AmpullaLock = ampulla_lock()
        if AmpullaLock then AmpullaLock.release() end
    end,
})
