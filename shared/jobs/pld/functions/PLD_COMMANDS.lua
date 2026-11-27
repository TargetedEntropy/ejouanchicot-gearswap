---  ═══════════════════════════════════════════════════════════════════════════
---   PLD Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Paladin job:
---   • Common commands (reload, checksets, waltz, jump, etc.)
---   • UI commands (toggle, update, reload UI)
---   • PLD-specific commands (aoe, rune)
---   • SCH subjob commands (lightarts, darkarts, aoe sneak/invi/erase) are
---     common commands
---   • Weaponskill slots (ws, ws1, ws2)
---   • State change hook (HybridMode profile, WS slots, Hoxne ammo lock)
---
---   Uses centralized command handlers for consistency across all jobs.
---
---   @file    shared/jobs/pld/functions/PLD_COMMANDS.lua
---   @author  ejouanchicot
---   @version 3.0.0 - Logic Extracted to logic/
---   @date    Created: 2025-10-03 | Updated: 2025-10-06
---   @requires shared/utils/ui/UI_COMMANDS, shared/utils/core/COMMON_COMMANDS
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════
-- Command handlers loaded on first command
local UICommands = nil
local CommonCommands = nil
local WatchdogCommands = nil
local CycleHandler = nil
local MessageCommands = nil

-- PLD logic modules
local AOEManager = nil
local RuneManager = nil

local function ensure_commands_loaded()
    if not UICommands then
        UICommands = require('shared/utils/ui/UI_COMMANDS')
        CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
        WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
        CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
        MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')

        -- PLD logic modules
        AOEManager = require('shared/jobs/pld/functions/logic/aoe_manager')
        RuneManager = require('shared/jobs/pld/functions/logic/rune_manager')
    end
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   Handle job-specific self commands (command router)
---   Processes commands in order: aoe (it must win over the common aoe) >>
---   JobCommands.shared (watchdog >> dual-box >> common >> UI >>
---   debugmidcast >> cyclestate) >> PLD-specific >> SCH >> WS slots
---
---   Common commands:
---   • reload         - Reload GearSwap
---   • checksets      - Validate equipment sets
---   • waltz <target> - Perform waltz on target
---   • jump           - Use DRG subjob Jump
---
---   UI commands:
---   • ui             - Toggle UI visibility
---
---   PLD-specific commands:
---   • aoe            - Execute Blue Magic AOE spell rotation (PLD/BLU)
---   • rune           - Execute Rune ability (PLD/RUN)
---
---   Weaponskill slots:
---   • ws / ws1 / ws2 - Fire the weaponskill the weapon in hand put in that slot
---
---   @param cmdParams table Command parameters array (e.g., {"aoe"})
---   @param eventArgs table Event arguments with handled flag
function job_self_command(cmdParams, eventArgs)
    if not cmdParams[1] then
        return
    end

    ensure_commands_loaded()

    local command = cmdParams[1]:lower()

    -- AOE: the bare word runs the Blue Magic rotation (PLD/BLU). Ahead of
    -- the common commands, which answer `aoe sneak|invi|erase` (/SCH)
    if command == 'aoe' and not cmdParams[2] then
        if AOEManager then
            AOEManager.execute_aoe()
            eventArgs.handled = true
        end
        return
    end

    if JobCommands.shared(command, cmdParams, eventArgs, 'PLD') then return end

    -- ══════════════════════════════════════════════════════════════════════════
    -- PLD-SPECIFIC COMMANDS
    -- ══════════════════════════════════════════════════════════════════════════

    -- Rune: Execute Rune ability (PLD/RUN)
    if command == 'rune' then
        if RuneManager then
            RuneManager.execute_rune()
            eventArgs.handled = true
        end
        return
    end

    -- Weaponskill slots: 'ws' is slot 1, 'ws1'/'ws2' name theirs. Each fires
    -- whatever the weapon currently in hand put in that slot.
    local slot = command == 'ws' and '1' or command:match('^ws([1-9])$')
    if slot then
        local ok, WSSlots = pcall(require, 'shared/utils/weaponskill/ws_slots')
        if ok and WSSlots then
            WSSlots.cast(tonumber(slot))
            eventArgs.handled = true
        end
        return
    end
end

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
