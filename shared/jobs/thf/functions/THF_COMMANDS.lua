---  ═══════════════════════════════════════════════════════════════════════════
---   THF Commands Module - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles custom commands for Thief job via //gs c syntax.
---
---   Features:
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
---   • SmartbuffManager (subjob-specific buff automation)
---
---   @file    shared/jobs/thf/functions/THF_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-06
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES
---  ═══════════════════════════════════════════════════════════════════════════
-- THF logic modules
local SmartbuffManager = require('shared/jobs/thf/functions/logic/smartbuff_manager')
local RangeLock = require('shared/jobs/thf/functions/logic/range_lock')

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   JOB SELF COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

--- THF's words (smartbuff is a common command).
job_self_command = JobCommands.router('THF', {
    words = {
        steal = function()
            SmartbuffManager.apply_steal()
        end,
        fbc = function()
            SmartbuffManager.apply_fbc()
        end,
        -- Pull: the player's ranged weapon (sets.RangeLock, else sets.precast.RA), range + ammo locked, /ra on the
        -- sub-target unless the ammo is unsafe
        range = function()
            RangeLock.pull()
        end,
    },
})

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
