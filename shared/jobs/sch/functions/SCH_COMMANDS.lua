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
---   None of them is a shared word (JobCommands.router).
---
---   @file    shared/jobs/sch/functions/SCH_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-29
---  ═══════════════════════════════════════════════════════════════════════════

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

local function spell(_, command)
    require('shared/jobs/sch/functions/logic/spell_commands').cast(command)
end

local function stratagems()
    require('shared/jobs/sch/functions/logic/spell_commands').show_stratagems()
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   JOB SELF COMMAND HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

job_self_command = JobCommands.router('SCH', {
    words = {
        nuke = spell, helix = spell, storm = spell,
        strat = stratagems, stratagems = stratagems,
        schhelp = function()
            show_help()
        end,
    },
})

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
