---  ═══════════════════════════════════════════════════════════════════════════
---   SAM Commands Module - Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Samurai job:
---   • Watchdog, dual-box, debugmidcast and cyclestate commands
---   • State change UI synchronization
---   • Stance commands: hasso, seigan (the stance the automation keeps)
---
---   @file    shared/jobs/sam/functions/SAM_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-21
---  ═══════════════════════════════════════════════════════════════════════════

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- hasso / seigan: choose the stance the automation keeps, and use it.
local function stance(_, command)
    local name = command == 'hasso' and 'Hasso' or 'Seigan'
    if state.Stance then state.Stance:set(name) end
    send_command('input /ja ' .. name .. ' <me>')
end

job_self_command = JobCommands.router('SAM', {
    words = {hasso = stance, seigan = stance},
})

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- SAM adds nothing of its own: the shared handler is the whole
--- behaviour. Pass a function to state_change() to extend it.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_self_command = job_self_command
_G.job_state_change = job_state_change
