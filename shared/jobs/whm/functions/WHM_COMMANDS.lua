---  ═══════════════════════════════════════════════════════════════════════════
---   WHM Commands Module - Command Handling & State Change Monitoring
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles user commands for White Mage:
---   • UI commands (ui, ui h, ui show, ui hide, ui toggle, ui update, ui reload)
---   • Common commands (reload, checksets, waltz, aoewaltz)
---   • WHM-specific commands (afflatus)
---   • State cycling commands (automatically handled by Mote-Include)
---   • State change monitoring (updates UI when states change)
---
---   @file    shared/jobs/whm/functions/WHM_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0.0
---   @date    Created: 2025-10-21
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
local WHMMessageFormatter = nil

local function ensure_commands_loaded()
    if not UICommands then
        UICommands = require('shared/utils/ui/UI_COMMANDS')
        CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
        WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
        CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
        MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')

        -- WHM message formatter
        local formatter_success
        formatter_success, WHMMessageFormatter = pcall(require, 'shared/utils/whm/whm_message_formatter')
        if not formatter_success then
            WHMMessageFormatter = nil
        end
    end
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

---   Handle user commands via //gs c <command>
---
---   @param cmdParams table Command parameters (cmdParams[1] = command name)
---   @param eventArgs table Event arguments (contains .handled flag)
---   @return void
function job_self_command(cmdParams, eventArgs)
    if not cmdParams or #cmdParams == 0 then
        return
    end

    -- Lazy load command handlers on first command
    ensure_commands_loaded()

    local command = cmdParams[1]:lower()

    if JobCommands.shared(command, cmdParams, eventArgs, 'WHM') then return end

    -- ══════════════════════════════════════════════════════════════════════════
    -- WHM-SPECIFIC COMMANDS
    -- ══════════════════════════════════════════════════════════════════════════

    -- Afflatus: Auto-cast current Afflatus stance
    if command == 'afflatus' then
        local stance = state.AfflatusMode.value

        if stance == 'Solace' then
            send_command('input /ja "Afflatus Solace" <me>')
            if WHMMessageFormatter then
                WHMMessageFormatter.show_afflatus_change('Solace')
            end
        elseif stance == 'Misery' then
            send_command('input /ja "Afflatus Misery" <me>')
            if WHMMessageFormatter then
                WHMMessageFormatter.show_afflatus_change('Misery')
            end
        end
        eventArgs.handled = true
        return
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   Called when a state variable changes (OffenseMode, IdleMode, etc.)
---   Handles weapon locking for melee mode AND updates UI.
---
---   The UI-aware cycle passes the state key ('CombatMode'), Mote passes the
---   description ('Combat Mode'); stripping spaces accepts both.
---
---   @param stateField string State key or description that changed
---   @param newValue string New value of the state
---   @param oldValue string Old value of the state
---   @return void
function job_state_change(stateField, newValue, oldValue)
    -- Skip UI update for Moving state (handled by AutoMove with flag)
    if stateField == 'Moving' then
        return
    end

    local field = type(stateField) == 'string' and stateField:gsub(' ', '') or stateField

    -- Combat Mode's weapon lock is shared/utils/core/combat_mode.lua's.

    -- ══════════════════════════════════════════════════════════════════════════
    -- OFFENSE MODE - WEAPON LOCK (the mode WHM_STATES defines: None / Melee ON)
    -- ══════════════════════════════════════════════════════════════════════════
    -- When switching to Melee ON, lock weapons to prevent accidental swaps.
    -- The lock is remembered on windower (it outlives a reload, like the
    -- lock itself): a subjob change resets OffenseMode to None through Mote's
    -- user_setup() before file_unload runs, so file_unload cannot read it
    -- from the mode.
    if field == 'OffenseMode' then
        -- Told to Combat Mode too: turning Combat Mode Off must not free
        -- the weapons while Melee ON still holds them.
        local CombatMode = require('shared/utils/core/combat_mode')
        if newValue == 'Melee ON' then
            disable('main', 'sub', 'range')
            windower._whm_melee_lock = true
            CombatMode.hold('whm_melee', {'main', 'sub', 'range'})
        else
            -- Not during a craft session: CraftManager owns the lock until
            -- //gs c uncraft, and enabling here would drop the synthesis gear.
            if not require('shared/utils/craft/craft_manager').is_active() then
                enable('main', 'sub', 'range')
                windower._whm_melee_lock = nil
                CombatMode.release('whm_melee')
            end
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- UI UPDATE (for all state changes)
    -- ══════════════════════════════════════════════════════════════════════════
    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        KeybindUI.update()
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_self_command = job_self_command
_G.job_state_change = job_state_change
