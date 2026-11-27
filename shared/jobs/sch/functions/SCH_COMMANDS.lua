---  ═══════════════════════════════════════════════════════════════════════════
---   SCH Commands Module - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   //gs c commands for Scholar.
---
---   Job commands:
---     lightarts        Light Arts, then Addendum: White on the next press
---     darkarts         Dark Arts, then Addendum: Black on the next press
---     nuke             the Element mode's nuke at Nuke Tier, on <t>
---     helix            the Element mode's helix (II, or I without it), on <t>
---     storm            the Element mode's storm (II, or I without it), on <me>
---     aoe sneak|invi|erase   Light Arts + Accession + the spell, party-wide
---                      (Sneak / Invisible follow Sneak/Invi AOE)
---     strat            Arts, stratagem charges, next charge, effects up
---     schhelp          the list above
---   lightarts, darkarts and aoe are common commands (ScholarActions, the
---   same on every job with /SCH); nuke / helix / storm are
---   logic/spell_commands.lua.
---
---   Order: JobCommands.shared (watchdog >> dual-box >> common >> UI >>
---   debugmidcast >> cyclestate) >> the SCH commands.
---
---   @file    shared/jobs/sch/functions/SCH_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0
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
---   JOB COMMANDS
---  ═══════════════════════════════════════════════════════════════════════════

--- //gs c schhelp
local function show_help()
    require('shared/utils/messages/help_screen').show({
        title = 'SCH', subtitle = 'Scholar commands',
        groups = {
            {title = 'ARTS', rows = {
                {'//gs c lightarts', '', 'Light Arts, then Addendum: White'},
                {'//gs c darkarts', '', 'Dark Arts, then Addendum: Black'},
                {'//gs c strat', '', 'Arts, charges, next charge, effects up'},
            }},
            {title = 'SPELLS', note = 'Element mode', rows = {
                {'//gs c nuke', '', 'Nuke at Nuke Tier on <t>'},
                {'//gs c helix', '', 'Helix II (or I) on <t>'},
                {'//gs c storm', '', 'Storm II (or I) on <me>'},
                {'//gs c aoe ', '<sneak|invi|erase>', 'Accession + the spell, party-wide'},
            }},
        },
        notes = {'A tier on recast or not learned drops to the next one down.'},
    })
end

--- Job commands: true when the command was one of them.
--- @param command string Lower-case command
--- @param cmdParams table Command parameters
--- @return boolean
local function handle_job_command(command, cmdParams)
    if command == 'nuke' or command == 'helix' or command == 'storm' then
        require('shared/jobs/sch/functions/logic/spell_commands').cast(command)
    elseif command == 'strat' or command == 'stratagems' then
        require('shared/jobs/sch/functions/logic/spell_commands').show_stratagems()
    elseif command == 'schhelp' then
        show_help()
    else
        return false
    end
    return true
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

    if handle_job_command(command, cmdParams) then
        eventArgs.handled = true
        return
    end

    if JobCommands.shared(command, cmdParams, eventArgs, 'SCH') then return end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- SCH adds nothing of its own: the shared handler repaints the HUD.
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
