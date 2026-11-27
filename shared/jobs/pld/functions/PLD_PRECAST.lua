---  ═══════════════════════════════════════════════════════════════════════════
---   PLD Precast Module - Precast Action Handling & Auto-Abilities
---  ═══════════════════════════════════════════════════════════════════════════
---   Debuff guard, cooldown check, auto-abilities (Majesty/Divine Emblem),
---   WS handling (with /SCH weaponskill variants), max-enmity override
---   (the Tanking stance).
---
---   @file    shared/jobs/pld/functions/PLD_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-05
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

local AbilityHelper = nil
local EnmityOverride = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local ah_ok, ah = pcall(require, 'shared/utils/precast/ability_helper')
    if not ah_ok then ah = nil end
    AbilityHelper = ah

    local eo_ok, eo = pcall(require, 'shared/jobs/pld/functions/logic/enmity_override')
    if not eo_ok then eo = nil end
    EnmityOverride = eo

    modules_loaded = true
end

-- Auto-abilities: Divine Emblem before Flash, Majesty before Protect/Cure
local auto_abilities = {
    ['Flash'] = function(spell, eventArgs)
        AbilityHelper.try_ability(spell, eventArgs, 'Divine Emblem', 2)
    end,
    ['Protect III'] = function(spell, eventArgs)
        AbilityHelper.try_ability_smart(spell, eventArgs, 'Majesty', 2)
    end,
    ['Protect IV'] = function(spell, eventArgs)
        AbilityHelper.try_ability_smart(spell, eventArgs, 'Majesty', 2)
    end,
    ['Protect V'] = function(spell, eventArgs)
        AbilityHelper.try_ability_smart(spell, eventArgs, 'Majesty', 2)
    end,
    ['Cure III'] = function(spell, eventArgs)
        AbilityHelper.try_ability_smart(spell, eventArgs, 'Majesty', 2)
    end,
    ['Cure IV'] = function(spell, eventArgs)
        AbilityHelper.try_ability_smart(spell, eventArgs, 'Majesty', 2)
    end
}

---   Swap in the /SCH variant of a weaponskill set, where one exists
---   PLD/SCH (and /RUN, the subjobs of PLDStates.stance_subjob in pld/keys/
---   PLD_STATES.lua) is the Sortie-only setup and builds its weaponskills
---   differently from the general tanking one, so sets.precast.WS.SCH holds the variants.
---   Runs in post_precast because Mote has laid down sets.precast.WS[name] by
---   then, and before apply_tp_gear so the TP bonus piece still wins.
---   @param spell table Spell/ability data
local function apply_sch_ws_set(spell)
    local states = rawget(_G, 'PLDStates')
    local stance_sub = states and states.stance_subjob and states.stance_subjob()
    if stance_sub == nil then stance_sub = player and player.sub_job == 'SCH' end
    if spell.type ~= 'WeaponSkill' or not stance_sub then
        return
    end

    local sch_sets = sets.precast and sets.precast.WS and sets.precast.WS.SCH
    local ws_set = sch_sets and (sch_sets[spell.english] or sch_sets[spell.name])
    if ws_set then
        -- the party support's version of it (.Solo, .Group, .Trust: shared/utils/party/support_tier.lua), as
        -- for the general weaponskill set
        equip(require('shared/utils/party/support_tier').engaged(ws_set))
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('PLD', {
    load = ensure_modules_loaded,
    -- Auto-abilities (Majesty, Divine Emblem), each one an option of PLD_CONFIG.lua (on unless set false)
    after_cooldown = function(spell, eventArgs)
        local option = spell.name == 'Flash' and 'pld_divine_emblem' or 'pld_majesty'
        if spell.action_type == 'Magic' and auto_abilities[spell.name] and AbilityHelper
            and require('shared/utils/core/auto_options').enabled(option, true) then
            auto_abilities[spell.name](spell, eventArgs)
        end
    end,
    before_tp_gear = function(spell, action, spellMap, eventArgs)
        apply_sch_ws_set(spell)
    end,
    after_tp_gear = function(spell, action, spellMap, eventArgs)
        -- Cure III/IV Self: low-HP FC set (Enif Cosciales) to minimize overcure waste
        -- Must be in post_precast to override Mote-Include's standard FC equip
        if (spell.name == 'Cure III' or spell.name == 'Cure IV')
            and spell.target and spell.target.type == 'SELF'
            and sets.precast and sets.precast.FC and sets.precast.FC.CureSelf then
            equip(sets.precast.FC.CureSelf)
        end

        -- Hate-holding modes: job abilities also get what sets.EnmityMax adds
        if EnmityOverride then
            EnmityOverride.apply_precast(spell)
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
