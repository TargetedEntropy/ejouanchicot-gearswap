---  ═══════════════════════════════════════════════════════════════════════════
---   THF Precast Module - Precast Action Handling & Cooldown Monitoring
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles all precast actions for Thief job with intelligent SA/TA combo
---   detection, treasure hunter tagging, and weaponskill optimization:
---   • Weaponskill precast (TP bonus optimization, SA/TA variants)
---   • Job ability and Fast Cast sets are left to Mote-Include
---   • Cooldown tracking with formatted messages
---   • Debuff guard integration (blocks actions if silenced/amnesia)
---   • WS range validation (6y melee, 15y ranged)
---   • TP bonus calculation (Moonshade Earring automation)
---   • SA/TA pending flag tracking (instant detection before buff appears)
---
---   Processing Order (CRITICAL - do not reorder):
---   1. Debuff guard (PrecastGuard) - blocks if silenced/amnesia/stunned
---   2. Cooldown check (CooldownChecker) - validates ability/spell ready
---   3. SA/TA pending flags (instant detection before buff appears)
---   4. WS validation (WSPrecastHandler) - TP check + range check
---   5. TP bonus calculation (TPBonusCalculator) - optimize WS gear
---   6. SA/TA variant selection (SATAManager) - apply set variants
---   7. TP bonus gear applied last (post-precast), over the variant
---
---   @file    shared/jobs/thf/functions/THF_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-06
---   @requires shared/jobs/thf/functions/logic/sa_ta_manager, WSPrecastHandler
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

local SATAManager = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local sm_ok, sm = pcall(require, 'shared/jobs/thf/functions/logic/sa_ta_manager')
    if not sm_ok then sm = nil end
    SATAManager = sm

    modules_loaded = true
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('THF', {
    load = ensure_modules_loaded,
    before_tp_gear = function(spell, action, spellMap, eventArgs)
        -- THF-SPECIFIC: Apply WS set variant based on SA/TA buffs.
        -- Before the TP gear: the variants are full WS sets and would overwrite
        -- the Moonshade Earring.
        if spell.type == 'WeaponSkill' and SATAManager then
            SATAManager.apply_variant(spell)
        end
    end,
})

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

-- Module table for require() compatibility (parity with _G exports above)
return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}
