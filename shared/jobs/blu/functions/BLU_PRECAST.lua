---  ═══════════════════════════════════════════════════════════════════════════
---   BLU Precast Module - Precast Action Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Processing order (do not reorder):
---   1. PrecastGuard       blocks under Silence / Amnesia / Stun..., cures
---                         with Remedy / Echo Drops when it can
---   2. CooldownChecker    ability / spell still on recast
---   3. Unbridled Learning before an unbridled spell (option blu_unbridled,
---                         logic/unbridled.lua)
---   4. Expiacion guard    held back under 3000 TP without Aftermath: Lv.3
---                         (option blu_expiacion_window, logic/expiacion_guard.lua)
---   5. WSPrecastHandler   range, 1000 TP minimum, TP bonus gear
---   Fast Cast, job ability and weaponskill sets are Mote's own picks
---   (sets.precast.FC['Blue Magic'], sets.precast.WS[name][WeaponskillMode]).
---
---   @file    shared/jobs/blu/functions/BLU_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-26
---   @requires PrecastPipeline
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

local BLUUnbridled = nil
local BLUExpiacionGuard = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local ul_ok, ul = pcall(require, 'shared/jobs/blu/functions/logic/unbridled')
    BLUUnbridled = ul_ok and ul or nil

    local ex_ok, ex = pcall(require, 'shared/jobs/blu/functions/logic/expiacion_guard')
    BLUExpiacionGuard = ex_ok and ex or nil

    modules_loaded = true
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('BLU', {
    load = ensure_modules_loaded,
    after_cooldown = function(spell, eventArgs)
        -- Unbridled Learning first for the spells that need it
        if BLUUnbridled then
            BLUUnbridled.apply(spell, eventArgs)
            if eventArgs.cancel or eventArgs.handled then
                return true
            end
        end
        return BLUExpiacionGuard and spell.type == 'WeaponSkill' and BLUExpiacionGuard.check(spell, eventArgs)
    end,
})

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}
