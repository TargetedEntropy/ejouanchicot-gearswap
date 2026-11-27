---  ═══════════════════════════════════════════════════════════════════════════
---   SCH Precast Module - Precast Action Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Processing order (do not reorder):
---   1. PrecastGuard       blocks under Silence / Amnesia / Stun..., cures
---                         with Remedy / Echo Drops when it can
---   2. Tier or recast     a tiered spell (nukes, -ra, Aspir, helices,
---                         storms: logic/spell_tiers.lua) goes to the shared
---                         TierRefiner, which drops it to the highest tier
---                         that can go out; anything else takes the
---                         CooldownChecker (stratagems are exempt there:
---                         they share one charge pool, recast 231)
---   3. Stratagem charges  a stratagem with no charge left is cancelled
---                         with the time to the next one
---   4. WSPrecastHandler   range, 1000 TP minimum, TP bonus gear
---   Post precast: TP bonus gear, then the grimoire layers
---   (logic/grimoire.lua: sets.precast.FC.Grimoire, Celerity, Alacrity).
---   Fast Cast, job ability and weaponskill sets are Mote's own picks
---   (sets.precast.FC[...], sets.precast.JA[name], sets.precast.WS[name]).
---
---   @file    shared/jobs/sch/functions/SCH_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-29
---   @requires PrecastGuard, CooldownChecker, TierRefiner, WSPrecastHandler
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

local TierRefiner = nil
local SpellTiers = nil
local Grimoire = nil

local modules_loaded = false

--- Every stratagem shares this recast slot (res/job_abilities.lua).
local STRATAGEM_RECAST_ID = 231

local function ensure_modules_loaded()
    if modules_loaded then return end

    local tr_ok, tr = pcall(require, 'shared/utils/precast/tier_refiner')
    TierRefiner = tr_ok and tr or nil

    local st_ok, st = pcall(require, 'shared/jobs/sch/functions/logic/spell_tiers')
    SpellTiers = st_ok and st or nil

    Grimoire = require('shared/jobs/sch/functions/logic/grimoire')
    modules_loaded = true
end

--- Stage 2: a tier downgrade for tiered spells, the recast check otherwise.
--- The checker would cancel a tiered spell before any downgrade could happen.
--- @param spell table Spell/ability data
--- @param eventArgs table Event arguments (cancel set when refused)
local function check_recast_or_refine(spell, eventArgs)
    local tiers = TierRefiner and SpellTiers and SpellTiers.get(spell)
    if tiers then
        TierRefiner.refine(spell, eventArgs, tiers)
    elseif spell.action_type == 'Ability' then
        PrecastPipeline.ability_cooldown(spell, eventArgs)
    elseif spell.action_type == 'Magic' then
        PrecastPipeline.spell_cooldown(spell, eventArgs)
    end
end

--- Stage 3: a stratagem with no charge left. The estimate never reads lower
--- than the real count (stratagem_charges.lua assumes the slowest recharge),
--- so a cast refused here would have been refused by the game.
--- @param spell table Spell/ability data
--- @param eventArgs table Event arguments (cancel set when no charge)
local function check_stratagem_charge(spell, eventArgs)
    if spell.type ~= 'JobAbility' or spell.recast_id ~= STRATAGEM_RECAST_ID then return end
    local Charges = require('shared/utils/scholar/stratagem_charges')
    if Charges.get_max() > 0 and Charges.available() == 0 then
        require('shared/utils/scholar/scholar_actions').warn_no_charge(spell.english)
        eventArgs.cancel = true
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('SCH', {
    load = ensure_modules_loaded,
    -- a spell with lower tiers is re-tiered instead of checked for recast
    cooldown = check_recast_or_refine,
    after_cooldown = function(spell, eventArgs)
        check_stratagem_charge(spell, eventArgs)
        return eventArgs.cancel
    end,
    after_tp_gear = function(spell, action, spellMap, eventArgs)
        Grimoire.equip_layers(Grimoire.precast_layers(spell))
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
