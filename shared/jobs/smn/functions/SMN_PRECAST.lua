---  ═══════════════════════════════════════════════════════════════════════════
---   SMN Precast Module - Precast Action Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Pipeline: PrecastGuard >> CooldownChecker >> WS
---
---   Blood Pacts are geared in MIDCAST (SMN_MIDCAST / SMN_PET_MIDCAST).
---   In precast Mote looks for sets.precast[spell.type] then sets.precast.JA
---   by name; with neither defined, a Blood Pact gets no precast gear.
---
---   @file    shared/jobs/smn/functions/SMN_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-05-28
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING
---  ═══════════════════════════════════════════════════════════════════════════

--- True when the master fires a /pet Blood Pact command.
--- @param spell table Spell/ability data
--- @return boolean
local function is_blood_pact(spell)
    return spell.type == 'BloodPactRage' or spell.type == 'BloodPactWard'
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('SMN')

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}
