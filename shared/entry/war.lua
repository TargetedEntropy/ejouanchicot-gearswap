---============================================================================
--- FFXI GearSwap Configuration - Warrior (WAR) - Modular Architecture
---============================================================================
--- Advanced Warrior job configuration built on modular architecture principles.
--- This file serves as the main coordinator, delegating all specialized logic
--- to dedicated modules for maximum maintainability and scalability.
---
--- @file    shared/entry/war.lua
--- @author  ejouanchicot
--- @version 2.1.0 - States Externalized
--- @date    Created: 2025-09-29 | Updated: 2025-10-14
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Key Features:
---   • Modular architecture with specialized function modules
---   • Externalized configuration (states, keybinds, lockstyle, macros)
---   • Comprehensive equipment set organization
---   • Clean separation of concerns
---
--- Architecture Overview:
---   EntryKit.job >> load_job >> Specialized Modules
---
--- Module Organization:
---   ├── <Character>/war/sets/war_sets.lua [Equipment Sets]
---   ├── functions/WAR_*.lua           [Hook Modules]
---   └── <Character>/war/<theme>/*.lua  [Configuration Files]
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with WAR's weaponskill slots and Ampulla lock
local CharPaths = require('shared/utils/core/char_paths')
local try_require = require('shared/utils/core/try_require')

--- Align state.MainWeapon (and the WS slots) with the weapon in hand.
--- WARStates.configure() runs from user_setup(), which Mote calls before
--- init_gear_sets() (Mote-Include.lua:170,175): the weapon sets do not exist
--- yet, so its sync cannot recognise the weapon and MainWeapon stays on its
--- first option. Called again here, once the sets are loaded.
local function sync_weapon_with_hand()
    local WSSlots = try_require('shared/utils/weaponskill/ws_slots')
    if not (WSSlots and _G.WARWSConfig and state.MainWeapon) then
        return
    end
    local before = state.MainWeapon.value
    WSSlots.sync(state.MainWeapon, _G.WARWSConfig)
    -- The keybind HUD was drawn in user_setup() with the old value
    local KeybindUI = state.MainWeapon.value ~= before and try_require('shared/utils/ui/UI_MANAGER')
    if KeybindUI then
        KeybindUI.update()
    end
end

require('shared/utils/core/entry_kit').job('WAR', {
    -- WS slot config must land BEFORE Mote-Include: including it runs init_include() -> user_setup() ->
    -- WARStates.configure(), which builds state.WS1..WS5 from this table. Loaded later it would still be nil.
    before_mote = function()
        _G.WARWSConfig = CharPaths.optional('job', 'WAR_WS_CONFIG', 'WAR')
    end,
    after_sets = sync_weapon_with_hand,
    -- configure() has just put HybridMode back to its default, so any ammo lock still held by the sandbox belongs to
    -- a stance that is no longer selected. GearSwap slot locks outlive the job file.
    after_states = function()
        local AmpullaLock = try_require('shared/utils/equipment/ampulla_lock')
        if AmpullaLock then AmpullaLock.apply(state.HybridMode and state.HybridMode.value) end
    end,
    -- Give the ammo slot back first: a GearSwap slot lock survives a job change, and GearSwap runs file_unload in a
    -- single pcall, so an error further down would otherwise leak the lock into the next job.
    unload = function()
        local AmpullaLock = try_require('shared/utils/equipment/ampulla_lock')
        if AmpullaLock then AmpullaLock.release() end
    end,
})
