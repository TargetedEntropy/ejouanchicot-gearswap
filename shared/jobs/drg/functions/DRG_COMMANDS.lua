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

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   JOB SELF COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

job_self_command = JobCommands.router('DRG', {
    first = {
        -- the first ready jump of DRGTPConfig.jumps, ahead of the common jump (/DRG only)
        jump = function(cmdParams, eventArgs)
            require('shared/jobs/drg/functions/logic/jumps').execute()
            eventArgs.handled = true
        end,
    },
})

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
