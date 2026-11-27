---  ═══════════════════════════════════════════════════════════════════════════
---   DNC Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Dancer job.
---
---   Features:
---   • Common commands integration (reload, checksets, waltz, aoewaltz, jump, ...)
---   • UI commands (ui, showbinds)
---   • Smartbuff command (selected dance + subjob buff automation)
---   • Step command with Presto integration
---   • Dance command (state.Dance: Saber Dance / Fan Dance)
---   • State change UI updates
---
---   Dependencies:
---   • UICommands - centralized UI command handling
---   • CommonCommands - universal job commands
---   • StepManager (logic) - Step + Presto management
---   • SmartbuffManager (logic) - Dance + subjob buff automation
---
---   @file    shared/jobs/dnc/functions/DNC_COMMANDS.lua
---   @author  ejouanchicot
---   @version 2.0 - Logic Extracted to logic/
---   @date    Created: 2025-10-04
---   @date    Updated: 2025-10-06
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
local StepManager = nil
local SmartbuffManager = nil

local function ensure_commands_loaded()
    if not UICommands then
        UICommands = require('shared/utils/ui/UI_COMMANDS')
        CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
        WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
        CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
        MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')

        -- Load DNC logic modules
        StepManager = require('shared/jobs/dnc/functions/logic/step_manager')
        SmartbuffManager = require('shared/jobs/dnc/functions/logic/smartbuff_manager')
    end
end

--- DNC's part of //gs c buff (shared/utils/buffs/buff_command.lua): the
--- selected dance, then the selected samba, before the job and subjob lists.
--- @return table abilities_to_cast, table status_data
function job_buff_extra()
    ensure_commands_loaded()
    return SmartbuffManager.collect_extra()
end
_G.job_buff_extra = job_buff_extra

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

    -- buff / smartbuff / buffself: the common command, which asks DNC for its
    -- dance and samba first (job_buff_extra below)

    if JobCommands.shared(command, cmdParams, eventArgs, 'DNC') then return end

    -- DNC-specific commands

    -- Step command with Presto integration
    if command == 'step' then
        StepManager.execute_step()
        eventArgs.handled = true
        return
    end

    -- Dance command (uses state.Dance to determine which dance to activate)
    if command == 'fandance' or command == 'dance' then
        SmartbuffManager.apply_dance()
        eventArgs.handled = true
        return
    end

    -- waltz / aoewaltz live in COMMON_COMMANDS so that WAR/DNC, NIN/DNC, etc.
    -- can use them too.
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

--- DNC adds nothing of its own: the shared handler is the whole
--- behaviour. Pass a function to state_change() to extend it.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export to global scope (used by Mote-Include via include())
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

