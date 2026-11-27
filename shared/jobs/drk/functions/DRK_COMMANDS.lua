---  ═══════════════════════════════════════════════════════════════════════════
---   DRK Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles custom commands for Dark Knight job (no DRK-specific command):
---   • Dual-box, watchdog, common and UI commands
---   • debugmidcast, cyclestate
---   • State change UI synchronization
---
---   Every command is a shared one: JobCommands (shared/utils/core/job_commands.lua).
---
---   @file    shared/jobs/drk/functions/DRK_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0.0
---   @date    Created: 2025-10-23
---   @requires shared/utils/core/job_commands
---  ═══════════════════════════════════════════════════════════════════════════

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   JOB SELF COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

job_self_command = JobCommands.router('DRK')

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- DRK adds nothing of its own: the shared handler is the whole
--- behaviour. Pass a function to state_change() to extend it.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export to global scope (used by Mote-Include via include())
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

