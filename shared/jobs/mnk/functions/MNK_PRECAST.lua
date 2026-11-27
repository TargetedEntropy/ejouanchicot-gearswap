---  ═══════════════════════════════════════════════════════════════════════════
---   MNK Precast Module - Precast Action Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Processing order (do not reorder):
---   1. PrecastGuard       blocks under Silence / Amnesia / Stun..., cures
---                         with Remedy / Echo Drops when it can
---   2. CooldownChecker    ability / spell still on recast
---   3. WSPrecastHandler   range, 1000 TP minimum, TP bonus gear
---   Job ability, weaponskill and Fast Cast sets are Mote's own picks
---   (sets.precast.JA[name], sets.precast.WS[name][WeaponskillMode],
---   sets.precast.FC). job_post_precast then lays, on a weaponskill, the
---   Impetus / Footwork layers (logic/buff_layers.lua), then the TP bonus
---   piece last so a layer cannot take its slot.
---   Nothing Monk does drops a tier: no exception before the cooldown check.
---
---   @file    shared/jobs/mnk/functions/MNK_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-29
---   @requires PrecastPipeline
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

local BuffLayers = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local bl_ok, bl = pcall(require, 'shared/jobs/mnk/functions/logic/buff_layers')
    BuffLayers = bl_ok and bl or nil

    modules_loaded = true
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('MNK', {
    load = ensure_modules_loaded,
    before_tp_gear = function(spell, action, spellMap, eventArgs)
        if BuffLayers and spell.type == 'WeaponSkill' then
            local laid = BuffLayers.equip_ws(spell)
            require('shared/utils/debug/trace_log').log('WS','%s -> WS mode %s, on top: %s', spell.english,
                tostring(state.WeaponskillMode and state.WeaponskillMode.current),
                #laid > 0 and table.concat(laid, ', ') or 'nothing')
        end
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
