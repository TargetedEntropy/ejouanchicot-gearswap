---  ═══════════════════════════════════════════════════════════════════════════
---   NIN Precast Module - Precast Action Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Processing order (do not reorder):
---   1. PrecastGuard       blocks under Silence / Amnesia / Stun..., cures
---                         with Remedy / Echo Drops when it can
---   2. CooldownChecker    ability / spell still on recast (Utsusemi
---                         included: a recast Utsusemi is cancelled, it
---                         does not drop to a lower tier)
---   3. WSPrecastHandler   range, 1000 TP minimum, TP bonus gear
---   Fast Cast, job ability, ranged and weaponskill sets are Mote's own
---   picks (sets.precast.FC, sets.precast.FC.Utsusemi, sets.precast.JA[name],
---   sets.precast.RA, sets.precast.WS[name][WeaponskillMode]).
---
---   @file    shared/jobs/nin/functions/NIN_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-29
---   @requires PrecastPipeline
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('NIN')

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}
