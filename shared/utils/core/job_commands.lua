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
--- changes nothing. A job gives its own words as a table, and the router
--- looks them up around the shared ones:
---
---   job_self_command = JobCommands.router('PLD', {
---       first = {aoe = fn},    -- words that win over a shared word of the same name (PLD / RUN 'aoe',
---                              -- DRG 'jump', BST 'debugprecast'); fn may return false to let the word through
---       words = {rune = fn},   -- the job's own words, never a shared one (scripts/atelier/job_commands_test.lua)
---       other = fn,            -- a word no table names (a pattern: ws1..ws9), fn(command, cmdParams, eventArgs)
---       load = fn,             -- the job's own modules, loaded at its first command
---   })
---
--- Each fn(cmdParams, eventArgs, command) sets eventArgs.handled itself, as
--- the job's branch did. A job with no word of its own: JobCommands.router('MNK').
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

--- A job's whole job_self_command.
--- @param job string The job's code
--- @param spec table|nil {first, words, other, load} (see the header)
--- @return function job_self_command
function JobCommands.router(job, spec)
    spec = spec or {}
    local first, words, other = spec.first or {}, spec.words or {}, spec.other
    JobCommands.specs[job] = spec
    return function(cmdParams, eventArgs)
        if not cmdParams[1] then return end
        if spec.load then spec.load() end
        local command = cmdParams[1]:lower()
        local fn = first[command]
        if fn and fn(cmdParams, eventArgs, command) ~= false then return end
        if JobCommands.shared(command, cmdParams, eventArgs, job) then return end
        fn = words[command]
        if fn then
            fn(cmdParams, eventArgs, command)
        elseif other then
            other(command, cmdParams, eventArgs)
        end
    end
end

--- An `other` for the weaponskill slots (shared/utils/weaponskill/ws_slots.lua): ws1..ws9 fire whatever the weapon
--- in hand put in that slot (ws6..ws9 have none and only warn).
--- @param bare_is_first boolean|nil true: 'ws' alone is slot 1 (PLD)
--- @return function other
function JobCommands.ws_slots(bare_is_first)
    return function(command, cmdParams, eventArgs)
        local slot = (bare_is_first and command == 'ws') and '1' or command:match('^ws([1-9])$')
        if not slot then return end
        local ok, WSSlots = pcall(require, 'shared/utils/weaponskill/ws_slots')
        if ok and WSSlots then
            WSSlots.cast(tonumber(slot))
            eventArgs.handled = true
        end
    end
end

--- What each job gave router() (the tests read it).
JobCommands.specs = {}

return JobCommands
