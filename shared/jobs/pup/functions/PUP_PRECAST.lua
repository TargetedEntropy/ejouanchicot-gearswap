---  ═══════════════════════════════════════════════════════════════════════════
---   PUP Precast Module - Precast Action Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Processing order (do not reorder):
---   1. PrecastGuard       blocks under Silence / Amnesia / Stun..., cures
---                         with Remedy / Echo Drops when it can
---   2. CooldownChecker    ability / spell still on recast (maneuvers too:
---                         one shared 10-second recast, no charges)
---   3. WSPrecastHandler   range, 1000 TP minimum, TP bonus gear
---   Fast Cast, job ability and weaponskill sets are Mote's own picks
---   (sets.precast.FC, sets.precast.JA[name], sets.precast.WS[name]); every
---   "<Element> Maneuver" maps to sets.precast.JA.Maneuver through
---   job_get_spell_map (PUP_MIDCAST.lua).
---
---   @file    shared/jobs/pup/functions/PUP_PRECAST.lua
---   @author  ejouanchicot
---   @version 2.0
---   @date    Created: 2026-09-29
---   @requires PrecastPipeline
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('PUP')

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}
