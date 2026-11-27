---============================================================================
--- Job Commands - the //gs c commands every job answers the same way
---============================================================================
--- One copy of the block every <JOB>_COMMANDS.lua used to paste at the head
--- of its job_self_command, in one fixed order:
---
---   watchdog >> altjobupdate / requestjob (dual-box) >> common commands
---   (COMMON_COMMANDS.lua: reload, checksets, warp, debug words...) >> ui >>
---   debugmidcast >> cyclestate
---
--- None of these words is a job command, so their order among themselves
--- changes nothing. A job word that must win over a common word of the same
--- name (PLD / RUN 'aoe', DRG 'jump', BST 'debugprecast') is tested by the job
--- before it calls JobCommands.shared; a job word tested after the call is
--- never a common word (scripts/atelier/job_commands_test.lua checks every job).
---
---   function job_self_command(cmdParams, eventArgs)
---       if not cmdParams[1] then return end
---       local command = cmdParams[1]:lower()
---       if command == 'aoe' then ... return end           -- wins over the common 'aoe'
---       if JobCommands.shared(command, cmdParams, eventArgs, 'PLD') then return end
---       ...                                                -- the job's own words
---   end
---
--- A job with no word of its own: job_self_command = JobCommands.router('MNK').
---
--- @file    shared/utils/core/job_commands.lua
---============================================================================
local JobCommands = {}

local CommonCommands, WatchdogCommands, UICommands, CycleHandler, MessageCommands

local function load()
    if CommonCommands then return end
    CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
    WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
    UICommands = require('shared/utils/ui/UI_COMMANDS')
    CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
    MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')
end

--- Answer a command shared by every job.
--- @param command string The first word, lower case
--- @param cmdParams table Every word, as Mote passes them
--- @param eventArgs table Mote's eventArgs: handled is set when Mote must not answer too
--- @param job string The job's code ('WAR'), for the common commands and the messages
--- @return boolean true when the command was one of them: the job's router returns
function JobCommands.shared(command, cmdParams, eventArgs, job)
    load()

    if WatchdogCommands.is_watchdog_command(command) then
        if WatchdogCommands.handle_command(cmdParams, eventArgs) then
            eventArgs.handled = true
        end
        return true
    end

    if command == 'altjobupdate' then
        if cmdParams[2] and cmdParams[3] then
            require('shared/utils/dualbox/dualbox_manager').receive_alt_job(cmdParams[2], cmdParams[3], cmdParams[4],
                cmdParams[5], cmdParams[6], cmdParams[7])
        end
        eventArgs.handled = true
        return true
    end

    if command == 'requestjob' then
        require('shared/utils/dualbox/dualbox_manager').handle_job_request()
        eventArgs.handled = true
        return true
    end

    if CommonCommands.is_common_command(command) then
        if CommonCommands.handle_command(command, job, unpack(cmdParams, 2)) then
            eventArgs.handled = true
        end
        return true
    end

    if UICommands.is_ui_command(command) then
        UICommands.handle_ui_command(cmdParams)
        eventArgs.handled = true
        return true
    end

    if command == 'debugmidcast' then
        require('shared/utils/midcast/midcast_manager').toggle_debug()
        MessageCommands.show_debugmidcast_toggled(job, _G.MidcastManagerDebugState)
        eventArgs.handled = true
        return true
    end

    -- UI-aware cycle: silent HUD update when the HUD is shown, Mote's message otherwise
    if command == 'cyclestate' then
        eventArgs.handled = CycleHandler.handle_cyclestate(cmdParams, eventArgs)
        return true
    end

    return false
end

--- The whole job_self_command of a job that has no command of its own.
--- @param job string The job's code
--- @return function job_self_command
function JobCommands.router(job)
    return function(cmdParams, eventArgs)
        if not cmdParams[1] then return end
        JobCommands.shared(cmdParams[1]:lower(), cmdParams, eventArgs, job)
    end
end

return JobCommands
