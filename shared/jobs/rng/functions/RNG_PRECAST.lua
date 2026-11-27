---  ═══════════════════════════════════════════════════════════════════════════
---   RNG Precast Module - Precast Action Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Processing order (do not reorder):
---   1. PrecastGuard       blocks under Silence / Amnesia / Stun..., cures
---                         with Remedy / Echo Drops when it can
---   2. CooldownChecker    ability / spell still on recast
---   3. Ranged attack      Flurry I / II groups for Mote's sets.precast.RA
---                         pick (logic/ranged.lua, shared FlurryTracker)
---   4. WSPrecastHandler   range, 1000 TP minimum, TP bonus gear
---   job_post_precast: WS TP bonus gear; on a ranged attack, the Velocity
---   Shot layer over the aim set.
---   Fast Cast, job ability and weaponskill sets are Mote's own picks
---   (sets.precast.FC, sets.precast.JA[name], sets.precast.WS[name]).
---   RNG has no tiered spell and no redirect: no exception before the
---   cooldown check.
---
---   @file    shared/jobs/rng/functions/RNG_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-29
---   @requires PrecastPipeline
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

local Ranged = require('shared/jobs/rng/functions/logic/ranged')

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('RNG', {
    after_cooldown = function(spell)
        if spell.action_type == 'Ranged Attack' then
            Ranged.prepare_precast()
        end
    end,
    after_tp_gear = function(spell, action, spellMap, eventArgs)
        if spell.action_type == 'Ranged Attack' then
            Ranged.equip_layers(Ranged.PRECAST_LAYERS, 'PRECAST')
        end
    end,
})

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Flurry I / II landing on this character (flurry_tracker.lua), once per load
Ranged.start()

_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}
