---  ═══════════════════════════════════════════════════════════════════════════
---   PUP Commands Module - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   //gs c commands for Puppetmaster.
---
---   Job command:
---     petmode          automaton head / frame, the Pet Mode they give, the
---                      Pet Mode in use, Pet WS, the automaton's TP
---     petmode auto     set Pet Mode from the head again (ends a value
---                      cycled by hand)
---
---   petmode is not a shared word (JobCommands.router).
---
---   @file    shared/jobs/pup/functions/PUP_COMMANDS.lua
---   @author  ejouanchicot
---   @version 2.0
---   @date    Created: 2026-09-29
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   PETMODE
---  ═══════════════════════════════════════════════════════════════════════════

--- //gs c petmode [auto]: show the automaton block, after re-detecting when
--- asked.
--- @param arg string|nil 'auto' to set Pet Mode from the head again
local function handle_petmode_command(arg)
    local Automaton = require('shared/jobs/pup/functions/logic/automaton')
    local PetWS = require('shared/jobs/pup/functions/logic/pet_ws')
    if arg and arg:lower() == 'auto' then
        Automaton.refresh_mode(true)
        send_command('gs c update')
    end
    local head, frame = Automaton.parts()
    local detected = Automaton.mode_for(head, frame)
    local out = Automaton.is_out()
    require('shared/utils/messages/info_block').show({
        tag = 'PUP', title = 'Automaton',
        fields = {
            {'Head', head or 'unknown', not head and 'dim' or nil},
            {'Frame', frame or 'unknown', not frame and 'dim' or nil},
            {'Head gives', detected or 'no mode', detected and 'good' or 'warn'},
            {'Pet Mode', state.PetMode and state.PetMode.current or '?'},
            {'Pet WS', PetWS.enabled()},
            {'Automaton', out and (Automaton.is_engaged() and 'fighting' or 'out') or 'not out', not out and 'dim' or nil},
            {'TP', out and (Automaton.tp() .. ' / ' .. PetWS.threshold()) or '-', PetWS.is_due() and 'good' or nil},
        },
        lines = {{'//gs c petmode auto: Pet Mode from the head again', 'dim'}},
    })
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   JOB SELF COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

job_self_command = JobCommands.router('PUP', {
    words = {
        petmode = function(cmdParams)
            handle_petmode_command(cmdParams[2])
        end,
    },
})

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- PUP adds nothing of its own: the shared handler repaints the HUD.
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
