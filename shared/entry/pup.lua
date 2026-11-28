---============================================================================
--- FFXI GearSwap Configuration - Puppetmaster (PUP) - Modular Architecture
---============================================================================
--- Loader for the Puppetmaster job: Mote-Include, the shared systems, the PUP
--- hook modules and this character's configs and sets.
---
--- @file shared/entry/pup.lua
--- @author ejouanchicot
--- @version 2.0
--- @date Created: 2026-09-29
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Architecture:
---   EntryKit.job >> load_job >> Hooks >> Logic Modules
---
--- Hooks Modules:
---   PUP_PRECAST | PUP_MIDCAST | PUP_PET_MIDCAST | PUP_AFTERCAST | PUP_STATUS
---   PUP_BUFFS | PUP_IDLE | PUP_ENGAGED | PUP_COMMANDS
---
--- Logic Modules:
---   logic/automaton.lua    - Head / frame -> PetMode, pet out / fighting / TP
---   logic/pet_ws.lua       - Automaton WS gear timing (0.5 s poll)
---   logic/set_builder.lua  - Idle / engaged sets, pet layers
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with PUP's automaton (PetMode from its head) and pet WS poll
local try_require = require('shared/utils/core/try_require')

require('shared/utils/core/entry_kit').job('PUP', {
    -- PetMode from the automaton's head before the HUD first draws it
    after_states = function()
        local Automaton = try_require('shared/jobs/pup/functions/logic/automaton')
        if Automaton then Automaton.refresh_mode(true) end
    end,
    -- before Mote puts the gear on (every gs c update, cycle, set, toggle): PetMode from a changed automaton head,
    -- the pet WS poll started if it has something to watch, then the HUD
    update = function()
        local Automaton = try_require('shared/jobs/pup/functions/logic/automaton')
        if Automaton then Automaton.refresh_mode() end
        local PetWS = try_require('shared/jobs/pup/functions/logic/pet_ws')
        if PetWS then PetWS.ensure_running() end
    end,
    unload = function()
        local PetWS = try_require('shared/jobs/pup/functions/logic/pet_ws')
        if PetWS then PetWS.stop() end
    end,
})
