---  ═══════════════════════════════════════════════════════════════════════════
---   WAR Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Warrior job:
---   • Common commands (reload, checksets, waltz, jump, etc.)
---   • UI commands (toggle, update, reload UI)
---   • WAR buff commands (berserk, defender, thirdeye, tp)
---   • Weaponskill slots (ws1..ws5)
---   • Retaliation debug (debugretaliation, retalstatus)
---   • State change UI synchronization
---
---   Uses centralized command handlers for consistency across all jobs.
---
---   @file    shared/jobs/war/functions/WAR_COMMANDS.lua
---   @author  ejouanchicot
---   @version 2.0.0
---   @date    Created: 2025-09-29
---   @requires shared/utils/ui/UI_COMMANDS, shared/utils/core/COMMON_COMMANDS
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════
-- Command handlers loaded on first command
local UICommands = nil
local CommonCommands = nil
local WatchdogCommands = nil
local MessageFormatter = nil
local CycleHandler = nil
local MessageCommands = nil

local function ensure_commands_loaded()
    if not UICommands then
        UICommands = require('shared/utils/ui/UI_COMMANDS')
        CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
        WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
        CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
        MessageFormatter = require('shared/utils/messages/message_formatter')
        MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')
    end
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   Handle job-specific self commands
---   Processes commands in order: JobCommands.shared (watchdog >> dual-box >> common >> UI >>
---   debugmidcast >> cyclestate) >> WAR-specific
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
---   WAR buff commands:
---   • berserk        - Buff with Berserk-focused abilities
---   • defender       - Buff with Defender-focused abilities
---   • thirdeye       - SAM subjob abilities (Hasso/Seigan + Third Eye)
---   • tp             - TP building (/SAM Meditate, /DRG Jump rotation)
---   • ws1..ws5       - Fire the weaponskill in that slot for the current weapon
---
---   @param cmdParams table Command parameters array (e.g., {"berserk"})
---   @param eventArgs table Event arguments with handled flag
---   @return void
function job_self_command(cmdParams, eventArgs)
    if not cmdParams[1] then
        return
    end

    -- Lazy load command handlers on first command
    ensure_commands_loaded()

    local command = cmdParams[1]:lower()

    if JobCommands.shared(command, cmdParams, eventArgs, 'WAR') then return end

    if command == 'debugretaliation' or command == 'debugretal' then
        -- Toggle Retaliation auto-cancel debug mode
        if toggle_retaliation_debug then
            toggle_retaliation_debug()
        else
            MessageFormatter.show_error('[WAR] Retaliation debug function not available')
        end

        eventArgs.handled = true
        return
    end

    if command == 'retalstatus' then
        -- Show Retaliation tracking status
        if get_retaliation_status then
            local status = get_retaliation_status()
            MessageFormatter.show_info('[WAR] Retaliation Status:')
            MessageFormatter.show_info('[WAR]   Debug Mode: ' .. tostring(status.debug_mode))
            MessageFormatter.show_info('[WAR]   Tracking: ' .. tostring(status.tracking))
            MessageFormatter.show_info('[WAR]   Elapsed Time: ' .. string.format('%.2f', status.elapsed_time) .. 's / ' .. status.move_duration_needed .. 's')
        else
            MessageFormatter.show_error('[WAR] Retaliation status function not available')
        end

        eventArgs.handled = true
        return
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- WAR-SPECIFIC BUFF COMMANDS
    -- ══════════════════════════════════════════════════════════════════════════

    -- Berserk mode: Buff WAR abilities excluding Defender
    if command == 'berserk' then
        if buff_war then
            buff_war('Berserk')
            eventArgs.handled = true
        end
        return
    end

    -- Defender mode: Buff WAR abilities excluding Berserk
    if command == 'defender' then
        if buff_war then
            buff_war('Defender')
            eventArgs.handled = true
        end
        return
    end

    -- SAM subjob: Hasso/Seigan + Third Eye
    if command == 'thirdeye' then
        if buff_sam_sub then
            buff_sam_sub()
            eventArgs.handled = true
        end
        return
    end

    -- TP building via subjob: /SAM -> Meditate, /DRG -> Jump rotation
    if command == 'tp' then
        if build_tp then
            build_tp()
            eventArgs.handled = true
        end
        return
    end

    -- Weaponskill slots: ws1..ws5 fire whatever the current weapon put there;
    -- ws6..ws9 have no slot and only warn.
    local slot = command:match('^ws([1-9])$')
    if slot then
        local ok, WSSlots = pcall(require, 'shared/utils/weaponskill/ws_slots')
        if ok and WSSlots then
            WSSlots.cast(tonumber(slot))
            eventArgs.handled = true
        end
        return
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   Update UI when state changes (MainWeapon, HybridMode, etc.)
---   Called by Mote-Include after any state change.
---
---   Mote passes the state description ('Main Weapon'); stripping spaces also
---   accepts the key ('MainWeapon'), so either spelling rebuilds the WS slots.
---
---   @param stateField string State key or description (e.g., "Main Weapon")
---   @param newValue   string New value
---   @param oldValue   string Previous value
---   @return void
function job_state_change(stateField, newValue, oldValue)
    -- Skip UI update for Moving state (handled by AutoMove with flag)
    if stateField == 'Moving' then
        return
    end

    local field = type(stateField) == 'string' and stateField:gsub(' ', '') or stateField

    -- Weapon changed: refill the WS slots from that weapon's list
    if field == 'MainWeapon' then
        local ok, WSSlots = pcall(require, 'shared/utils/weaponskill/ws_slots')
        if ok and WSSlots and _G.WARWSConfig then
            WSSlots.rebuild(_G.WARWSConfig.get(newValue), _G.WARWSConfig.max_slots)
        end
        -- The Aftermath Set key only shows for a weapon with its own AFM3 set
        if _G.WARKeybinds and type(_G.WARKeybinds.refresh) == 'function' then
            _G.WARKeybinds.refresh()
        end
    end

    -- The Hoxne stance holds the ammo slot on its Ampulla; every other
    -- stance gives the slot back.
    if field == 'HybridMode' then
        local al_ok, AmpullaLock = pcall(require, 'shared/utils/equipment/ampulla_lock')
        if al_ok and AmpullaLock then
            AmpullaLock.apply(newValue)
        end
    end

    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        KeybindUI.update()
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export globally for GearSwap
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

