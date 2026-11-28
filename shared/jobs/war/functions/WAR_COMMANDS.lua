---  ═══════════════════════════════════════════════════════════════════════════
---   WAR Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Warrior job:
---   • WAR buff commands (berserk, defender, thirdeye, tp)
---   • Weaponskill slots (ws1..ws5)
---   • Retaliation debug (debugretaliation, retalstatus)
---   • State change UI synchronization
---
---   The words every job shares go through JobCommands.router (shared/utils/core/job_commands.lua).
---
---   @file    shared/jobs/war/functions/WAR_COMMANDS.lua
---   @author  ejouanchicot
---   @version 2.0.0
---   @date    Created: 2025-09-29
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════
local MessageFormatter = nil

local function ensure_commands_loaded()
    if not MessageFormatter then
        MessageFormatter = require('shared/utils/messages/message_formatter')
    end
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

local function retaliation_debug()
    if toggle_retaliation_debug then
        toggle_retaliation_debug()
    else
        MessageFormatter.show_error('[WAR] Retaliation debug function not available')
    end
end

--- WAR's words: the buff routines (berserk / defender: WAR abilities without the other one; thirdeye: /SAM
--- Hasso or Seigan + Third Eye; tp: /SAM Meditate, /DRG Jump rotation), the Retaliation auto-cancel debug, and the
--- weaponskill slots ws1..ws5 (ws6..ws9 have no slot and only warn).
job_self_command = JobCommands.router('WAR', {
    load = ensure_commands_loaded,
    words = {
        debugretaliation = retaliation_debug,
        debugretal = retaliation_debug,
        retalstatus = function()
            if get_retaliation_status then
                local status = get_retaliation_status()
                MessageFormatter.show_info('[WAR] Retaliation Status:')
                MessageFormatter.show_info('[WAR]   Debug Mode: ' .. tostring(status.debug_mode))
                MessageFormatter.show_info('[WAR]   Tracking: ' .. tostring(status.tracking))
                MessageFormatter.show_info('[WAR]   Elapsed Time: ' .. string.format('%.2f', status.elapsed_time) .. 's / ' .. status.move_duration_needed .. 's')
            else
                MessageFormatter.show_error('[WAR] Retaliation status function not available')
            end
        end,
        -- the buff routines (WAR_BUFFS / logic/smartbuff_manager), left to Mote while one is not defined
        berserk = function()
            if not buff_war then return false end
            buff_war('Berserk')
        end,
        defender = function()
            if not buff_war then return false end
            buff_war('Defender')
        end,
        thirdeye = function()
            if not buff_sam_sub then return false end
            buff_sam_sub()
        end,
        tp = function()
            if not build_tp then return false end
            build_tp()
        end,
    },
    other = JobCommands.ws_slots(),
})

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

