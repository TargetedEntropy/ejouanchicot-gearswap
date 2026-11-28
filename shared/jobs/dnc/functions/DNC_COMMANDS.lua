---  ═══════════════════════════════════════════════════════════════════════════
---   DNC Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Dancer job.
---
---   Features:
---   • Common commands integration (reload, checksets, waltz, aoewaltz, jump, ...)
---   • Smartbuff command (selected dance + subjob buff automation)
---   • Step command with Presto integration
---   • Dance command (state.Dance: Saber Dance / Fan Dance)
---   • State change UI updates
---
---   Dependencies:
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
-- DNC logic modules, loaded on first command
local StepManager = nil
local SmartbuffManager = nil

local function ensure_commands_loaded()
    if not StepManager then
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

--- buff / smartbuff / buffself are common commands, which ask DNC for its dance and samba first (job_buff_extra
--- above); waltz / aoewaltz too, so that WAR/DNC, NIN/DNC, etc. can use them.
local function dance()
    SmartbuffManager.apply_dance()
end

job_self_command = JobCommands.router('DNC', {
    load = ensure_commands_loaded,
    words = {
        -- Step with Presto
        step = function()
            StepManager.execute_step()
        end,
        -- the dance state.Dance selects
        fandance = dance,
        dance = dance,
    },
})

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

