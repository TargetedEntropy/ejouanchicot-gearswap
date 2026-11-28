---  ═══════════════════════════════════════════════════════════════════════════
---   PLD Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Paladin job:
---   • PLD-specific commands (aoe, rune)
---   • SCH subjob commands (lightarts, darkarts, aoe sneak/invi/erase) are
---     common commands
---   • Weaponskill slots (ws, ws1, ws2)
---   • State change hook (HybridMode profile, WS slots, Hoxne ammo lock)
---
---   The words every job shares go through JobCommands.router (shared/utils/core/job_commands.lua).
---
---   @file    shared/jobs/pld/functions/PLD_COMMANDS.lua
---   @author  ejouanchicot
---   @version 3.0.0 - Logic Extracted to logic/
---   @date    Created: 2025-10-03 | Updated: 2025-10-06
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════
-- PLD logic modules, loaded on first command
local AOEManager = nil
local RuneManager = nil

local function ensure_commands_loaded()
    if not AOEManager then
        AOEManager = require('shared/jobs/pld/functions/logic/aoe_manager')
        RuneManager = require('shared/jobs/pld/functions/logic/rune_manager')
    end
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   PLD's words, around the shared ones (JobCommands.router):
---   aoe              Blue Magic AOE rotation (PLD/BLU), ahead of the common aoe
---   rune             Rune ability (PLD/RUN)
---   ws / ws1 / ws2   the weaponskill the weapon in hand put in that slot
job_self_command = JobCommands.router('PLD', {
    load = ensure_commands_loaded,
    first = {
        -- the bare word runs the Blue Magic rotation (PLD/BLU); `aoe sneak|invi|erase` (/SCH) goes on to the
        -- common commands
        aoe = function(cmdParams, eventArgs)
            if cmdParams[2] then return false end
            AOEManager.execute_aoe()
            eventArgs.handled = true
        end,
    },
    words = {
        rune = function(cmdParams, eventArgs)
            RuneManager.execute_rune()
            eventArgs.handled = true
        end,
    },
    other = JobCommands.ws_slots(true),  -- ws / ws1 / ws2: the weaponskill in that slot
})

---   Rebuild the weaponskill slots for the weapon now in hand
---   Both the weapon choice and the stance can change it: under /SCH the
---   Tanking stance holds Burtgang whatever state.MainWeapon says, so a
---   HybridMode change moves the main hand as surely as Ctrl+Numpad1 does.
local function rebuild_ws_slots()
    local ws_ok, WSSlots = pcall(require, 'shared/utils/weaponskill/ws_slots')
    local sb_ok, SetBuilder = pcall(require, 'shared/jobs/pld/functions/logic/set_builder')
    local config = _G.PLDWSConfig

    if not (ws_ok and sb_ok and WSSlots and SetBuilder and config) then
        return
    end

    WSSlots.rebuild(config.get(SetBuilder.current_weapon()), config.max_slots)
end

_G.pld_rebuild_ws_slots = rebuild_ws_slots

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

local LifecycleManager = require('shared/utils/core/lifecycle_manager')

--- React to a HybridMode change by reshaping the states that depend on it
--- (rune list, Phalanx default). The profile itself lives in the character's
--- PLD_STATES config, reached through _G because its path carries the
--- character name; a config without it simply gets nothing.
---
--- Every cycle path passes the state's description ('Hybrid Mode'); the
--- UI-aware handler falls back to the state key ('HybridMode') only for a
--- state without one. Stripping spaces accepts both.
---
---   @param stateField string State key or description of what changed
---   @param newValue string New value of that state
local function on_state_change(stateField, newValue)
    if type(stateField) ~= 'string' then
        return
    end

    local field = stateField:gsub(' ', '')

    if field == 'MainWeapon' or field == 'StanceWeapon' then
        rebuild_ws_slots()
        return
    end

    if field ~= 'HybridMode' then
        return
    end

    local PLDStates = _G.PLDStates
    if PLDStates and type(PLDStates.apply_hybrid_profile) == 'function' then
        PLDStates.apply_hybrid_profile(newValue)
    end

    rebuild_ws_slots()

    -- The Hoxne stance holds the ammo slot on its Ampulla; every other stance
    -- gives the slot back. Kept here rather than in the profile because it
    -- equips gear, which a states config has no business doing.
    local ok, AmpullaLock = pcall(require, 'shared/utils/equipment/ampulla_lock')
    if ok and AmpullaLock then
        AmpullaLock.apply(newValue)
    end

    -- A stance change can add or remove a bind: /SCH Tanking holds the weapon,
    -- so MainWeapon has nothing to cycle there. The HUD re-reads the bind list
    -- on every refresh; the keys themselves are only laid down by bind_all.
    if _G.PLDKeybinds and type(_G.PLDKeybinds.refresh) == 'function' then
        _G.PLDKeybinds.refresh()
    end
end

job_state_change = LifecycleManager.state_change(on_state_change)

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export globally for GearSwap
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change
