---  ═══════════════════════════════════════════════════════════════════════════
---   DRK Precast Module - Precast Action Handling & Fast Cast
---  ═══════════════════════════════════════════════════════════════════════════
---   Debuff guard, cooldown check, Dark Seal / Nether Void pending flags,
---   WS handling, JA gear (Last Resort, Weapon Bash, Souleater, Arcane
---   Circle), Fast Cast for magic, TP bonus gear.
---
---   @file    shared/jobs/drk/functions/DRK_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-05
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('DRK', {
    after_cooldown = function(spell)
        if spell.type == 'JobAbility' then
            if spell.name == 'Dark Seal' then
                _G.drk_dark_seal_pending = true
            elseif spell.name == 'Nether Void' then
                _G.drk_nether_void_pending = true
            end
        end
    end,
    after_ws = function(spell)
        if spell.type == 'JobAbility' then
            if spell.name == 'Last Resort' and sets.precast and sets.precast.JA and sets.precast.JA['Last Resort'] then
                equip(sets.precast.JA['Last Resort'])
            elseif spell.name == 'Weapon Bash' and sets.precast and sets.precast.JA and sets.precast.JA['Weapon Bash'] then
                equip(sets.precast.JA['Weapon Bash'])
            elseif spell.name == 'Souleater' and sets.precast and sets.precast.JA and sets.precast.JA['Souleater'] then
                equip(sets.precast.JA['Souleater'])
            elseif spell.name == 'Arcane Circle' and sets.precast and sets.precast.JA and sets.precast.JA['Arcane Circle'] then
                equip(sets.precast.JA['Arcane Circle'])
            end
        end
        if spell.action_type == 'Magic' and sets.precast and sets.precast.FC then
            equip(sets.precast.FC)
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

