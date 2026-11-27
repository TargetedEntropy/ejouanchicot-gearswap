---  ═══════════════════════════════════════════════════════════════════════════
---   THF Commands Module - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles custom commands for Thief job via //gs c syntax.
---
---   Features:
---   • Common commands (reload, checksets, etc. via COMMON_COMMANDS)
---   • UI commands (ui toggle, visibility via UI_COMMANDS)
---   • THF-specific commands (fbc, steal, range)
---   • Ranged weapon lock with auto-attack (one-way: equip >> lock >> /ra)
---   • State change: UI refresh, range/ammo lock when RangeLock changes
---
---   Commands:
---   • //gs c reload         - Reload THF configuration
---   • //gs c checksets      - Validate equipment sets
---   • //gs c buff           - Job + subjob buffs (common command, buff_command.lua)
---   • //gs c fbc            - Feint / Bully / Conspirator opener
---   • //gs c steal          - Steal / Mug / Despoil on <t>
---   • //gs c range          - Equip + lock ranged + attack <stnpc> (one-way)
---   • //gs c ui             - Toggle UI visibility
---
---   Dependencies:
---   • CommonCommands (universal commands: reload, checksets, etc.)
---   • UICommands (UI toggle and management)
---   • SmartbuffManager (subjob-specific buff automation)
---
---   @file    shared/jobs/thf/functions/THF_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-06
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
local SmartbuffManager = nil
local RangeLock = nil

local function ensure_commands_loaded()
    if not UICommands then
        UICommands = require('shared/utils/ui/UI_COMMANDS')
        CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
        WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
        CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
        MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')

        -- Load THF logic modules
        SmartbuffManager = require('shared/jobs/thf/functions/logic/smartbuff_manager')
        RangeLock = require('shared/jobs/thf/functions/logic/range_lock')
    end
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   JOB SELF COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

---   Handle job-specific self commands
---   @param cmdParams table Command parameters array
---   @param eventArgs table Event arguments with handled flag
function job_self_command(cmdParams, eventArgs)
    if not cmdParams[1] then return end

    -- Lazy load command handlers on first command
    ensure_commands_loaded()

    local command = cmdParams[1]:lower()

    if command == 'steal' then
        SmartbuffManager.apply_steal()
        eventArgs.handled = true
        return
    end

    if JobCommands.shared(command, cmdParams, eventArgs, 'THF') then return end

    -- THF-specific commands (smartbuff is a common command)
    if command == 'fbc' then
        SmartbuffManager.apply_fbc()
        eventArgs.handled = true
        return
    end

    -- Pull: the player's ranged weapon (sets.RangeLock, else sets.precast.RA),
    -- range + ammo locked, /ra on the sub-target unless the ammo is unsafe
    if command == 'range' then
        RangeLock.pull()
        eventArgs.handled = true
        return
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

local LifecycleManager = require('shared/utils/core/lifecycle_manager')

--- Lock or unlock range and ammo when RangeLock changes.
---
--- The field is compared with spaces stripped, so the state key ('RangeLock')
--- and the description Mote passes ('Range Lock') both match.
---
---   @param stateField string State key or description of what changed
---   @return void
local function on_state_change(stateField)
    if type(stateField) ~= 'string' or stateField:gsub(' ', '') ~= 'RangeLock' then
        return
    end
    if not state.RangeLock then
        return
    end

    local locked = state.RangeLock.value == true
    require('shared/jobs/thf/functions/logic/range_lock').set_slots(locked)

    local ok, MessageFormatter = pcall(require, 'shared/utils/messages/message_formatter')
    if ok and MessageFormatter then
        MessageFormatter.show_success(locked and "Ranged weapons locked" or "Ranged weapons unlocked")
    end
end

job_state_change = LifecycleManager.state_change(on_state_change)

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_self_command = job_self_command
_G.job_state_change = job_state_change
