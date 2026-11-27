---  ═══════════════════════════════════════════════════════════════════════════
---   DRG Commands Module - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   //gs c commands for Dragoon.
---
---   Job command:
---     jump             the first ready jump of DRGTPConfig.jumps
---                      (logic/jumps.lua). Taken here before the common
---                      `jump`, which serves /DRG only.
---
---   Order: jump (it must win over the common jump) >> JobCommands.shared (watchdog >> dual-box >> common >> UI >>
---   debugmidcast >> cyclestate).
---
---   @file    shared/jobs/drg/functions/DRG_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-29
---  ═══════════════════════════════════════════════════════════════════════════

local UICommands = nil
local CommonCommands = nil
local WatchdogCommands = nil
local CycleHandler = nil
local MessageCommands = nil

local function ensure_commands_loaded()
    if UICommands then return end
    UICommands = require('shared/utils/ui/UI_COMMANDS')
    CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
    WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
    CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
    MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   JOB SELF COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

---   Handle job self commands (router)
---   @param cmdParams table Command parameters array
---   @param eventArgs table Event arguments with handled flag
function job_self_command(cmdParams, eventArgs)
    if not cmdParams[1] then return end
    ensure_commands_loaded()
    local command = cmdParams[1]:lower()

    if command == 'jump' then
        require('shared/jobs/drg/functions/logic/jumps').execute()
        eventArgs.handled = true
        return
    end

    if JobCommands.shared(command, cmdParams, eventArgs, 'DRG') then return end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- DRG adds nothing of its own: the shared handler repaints the HUD.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

return {
    job_self_command = job_self_command,
    job_state_change = job_state_change,
}
