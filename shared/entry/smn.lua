---============================================================================
--- FFXI GearSwap Configuration - Summoner (SMN) - Modular Architecture
---============================================================================
--- Summoner job entry point. Delegates all logic to specialized modules under
--- shared/jobs/smn/. Blood Pact routing lives in SMN_MIDCAST + the dedicated
--- blood_pact_classifier logic module.
---
--- @file    shared/entry/smn.lua
--- @author  ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date    Created: 2026-05-28
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with SMN's Carbuncle at load and its skillup loop stopped at unload (no TP configuration)
local LockstyleConfig

LockstyleConfig = require('shared/utils/core/entry_kit').job('SMN', {
    tp_config = false,
    -- Auto-summon Carbuncle when no pet is out (runs on load and on every subjob change, since both go through
    -- user_setup). Through LoadGate: on a subjob change Mote runs user_setup in the old environment and again after
    -- the reload, and only the reload's summon must go out
    after_setup = function()
        require('shared/utils/core/load_gate').defer(LockstyleConfig.initial_load_delay + 2.0, function()
            if player and player.main_job == 'SMN' and player.status ~= 'Dead' then
                local pet = windower.ffxi.get_mob_by_target('pet')
                if not pet or not pet.id or pet.id == 0 then
                    send_command('input /ma "Carbuncle" <me>')
                end
            end
        end, 'smn summon')
    end,
    -- Halt the Summoning Magic skillup loop before module unload so orphan coroutines can't keep spamming Siren on
    -- the next job.
    unload = function()
        if _G.cancel_smn_skillup_loop then
            pcall(_G.cancel_smn_skillup_loop)
        end
    end,
})
