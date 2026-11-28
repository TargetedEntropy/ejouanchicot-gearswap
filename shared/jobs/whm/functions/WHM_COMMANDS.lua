---  ═══════════════════════════════════════════════════════════════════════════
---   WHM Commands Module - Command Handling & State Change Monitoring
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles user commands for White Mage:
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
---   DEPENDENCIES
---  ═══════════════════════════════════════════════════════════════════════════
-- WHM message formatter (nil when it does not load)
local try_require = require('shared/utils/core/try_require')
local WHMMessageFormatter = try_require('shared/utils/whm/whm_message_formatter')

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

--- afflatus: use the Afflatus stance state.AfflatusMode selects.
job_self_command = JobCommands.router('WHM', {
    words = {
        afflatus = function()
            local stance = state.AfflatusMode.value
            if stance == 'Solace' or stance == 'Misery' then
                send_command('input /ja "Afflatus ' .. stance .. '" <me>')
                if WHMMessageFormatter then
                    WHMMessageFormatter.show_afflatus_change(stance)
                end
            end
        end,
    },
})

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
