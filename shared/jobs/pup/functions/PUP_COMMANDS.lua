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
---   Order: petmode >> JobCommands.shared (watchdog >> dual-box >> common >> UI >>
---   debugmidcast >> cyclestate).
---
---   @file    shared/jobs/pup/functions/PUP_COMMANDS.lua
---   @author  ejouanchicot
---   @version 2.0
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

---   Handle job self commands (router)
---   @param cmdParams table Command parameters array
---   @param eventArgs table Event arguments with handled flag
function job_self_command(cmdParams, eventArgs)
    if not cmdParams[1] then return end
    ensure_commands_loaded()
    local command = cmdParams[1]:lower()

    if command == 'petmode' then
        handle_petmode_command(cmdParams[2])
        eventArgs.handled = true
        return
    end

    if JobCommands.shared(command, cmdParams, eventArgs, 'PUP') then return end
end

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
