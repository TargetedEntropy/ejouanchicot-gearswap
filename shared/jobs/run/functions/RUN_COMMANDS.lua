---  ═══════════════════════════════════════════════════════════════════════════
---   RUN Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Rune Fencer job:
---   • RUN-specific commands (aoe, rune)
---   • State change UI synchronization
---
---   The words every job shares go through JobCommands.router (shared/utils/core/job_commands.lua).
---
---   @file    shared/jobs/run/functions/RUN_COMMANDS.lua
---   @author  ejouanchicot
---   @version 3.0.0 - Logic Extracted to logic/
---   @date    Created: 2025-10-03 | Updated: 2025-10-06
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES
---  ═══════════════════════════════════════════════════════════════════════════
-- RUN logic modules
local JobCommands = require('shared/utils/core/job_commands')
-- a handler that returns PASS leaves the word unanswered (JobCommands.router)
local PASS = JobCommands.PASS

local AOEManager = require('shared/jobs/run/functions/logic/aoe_manager')
local RuneManager = require('shared/jobs/run/functions/logic/rune_manager')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   RUN's words, around the shared ones (JobCommands.router):
---   aoe              Blue Magic AOE rotation (RUN/BLU), ahead of the common aoe
---   rune             the rune selected in state.RuneMode
job_self_command = JobCommands.router('RUN', {
    first = {
        -- the bare word runs the Blue Magic rotation (RUN/BLU); `aoe sneak|invi|erase` (/SCH) goes on to the
        -- common commands
        aoe = function(cmdParams)
            if cmdParams[2] then return PASS end
            AOEManager.execute_aoe()
        end,
    },
    words = {
        rune = function()
            RuneManager.execute_rune()
        end,
    },
})

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- RUN adds nothing of its own: the shared handler is the whole
--- behaviour. Pass a function to state_change() to extend it.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export globally for GearSwap
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change
