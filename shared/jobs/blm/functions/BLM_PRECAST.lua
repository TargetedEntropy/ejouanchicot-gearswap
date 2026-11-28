---  ═══════════════════════════════════════════════════════════════════════════
---   BLM Precast Module - Precast Action Handling & Intelligent Spell Refinement
---  ═══════════════════════════════════════════════════════════════════════════
---   Precast pipeline for Black Mage (precast gear itself comes from the
---   sets through Mote):
---   • PrecastGuard first (debuffs that block the action)
---   • Recast check, or tier refinement for the spells that have tiers
---     (Elemental Magic except storms/Klimaform, plus the enfeebling and dark
---     spells listed in BLM_SPELL_FILTERS.REFINEMENT_SPELLS)
---   • Stratagem charge abilities skip the cooldown check
---   • Dark Arts before a nuke on BLM/SCH (checkArts)
---   • WSPrecastHandler for weaponskills
---
---   @file    shared/jobs/blm/functions/BLM_PRECAST.lua
---   @author  ejouanchicot
---   @version 2.0 - Universal Refinement Integration
---   @date    Created: 2025-10-15 | Updated: 2025-10-15
---   @requires Tetsouo architecture, MessageFormatter, CooldownChecker, spell_refiner
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

local BLM_SPELL_FILTERS = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    -- Load BLM spell filters (cached by Lua after first require)
    local filters_ok, filters = pcall(require, 'shared/data/spells/BLM_SPELL_FILTERS')
    if not filters_ok then filters = nil end
    BLM_SPELL_FILTERS = filters

    modules_loaded = true
end

-- NOTE: BLM logic functions are loaded globally via blm_functions.lua:
--   • refine_various_spells() - Spell tier downgrading
--   • checkArts() - Scholar subjob Dark Arts automation
-- These functions are available in _G scope and called directly

---  ═══════════════════════════════════════════════════════════════════════════
---   HELPER FUNCTIONS (Lazy Loaded - Safe to Call After ensure_modules_loaded)
---  ═══════════════════════════════════════════════════════════════════════════

---   Check if an ability has multiple charges (bypass cooldown check)
---   @param spell table Spell object
---   @return boolean true if ability has charges
local function has_charges(spell)
    return BLM_SPELL_FILTERS and BLM_SPELL_FILTERS.CHARGE_ABILITIES[spell.english] or false
end

---   Check if a spell should use refinement instead of cooldown check
---   @param spell table Spell object
---   @return boolean true if spell uses refinement
local function uses_refinement(spell)
    if not BLM_SPELL_FILTERS then return false end

    -- Check by skill first (Elemental Magic), but exclude Storm/Klimaform (no tiers)
    if spell.skill == 'Elemental Magic' then
        if BLM_SPELL_FILTERS.ELEMENTAL_NO_TIERS[spell.english] then
            return false
        end
        return true
    end

    -- Check by spell name for other tiered spells
    return BLM_SPELL_FILTERS.REFINEMENT_SPELLS[spell.english] or false
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST STEPS
---  ═══════════════════════════════════════════════════════════════════════════

--- Stage 2: recast, or a tier downgrade for the spells that have one.
---
--- Three routes, and which one applies is not obvious from the call site.
--- Stratagems hold charges, so FFXI blocks them itself and a cooldown check
--- would refuse a cast the game would have allowed. Tiered spells go through
--- refinement, which checks the recast itself and steps down a tier rather
--- than cancelling. Everything else takes the plain check.
local function check_recast_or_refine(spell, action, spellMap, eventArgs)
    if spell.action_type == 'Ability' then
        if not has_charges(spell) then
            PrecastPipeline.ability_cooldown(spell, action, spellMap, eventArgs)
        end

    elseif spell.action_type == 'Magic' then
        if uses_refinement(spell) then
            if refine_various_spells then
                refine_various_spells(spell, eventArgs)
            end
        else
            PrecastPipeline.spell_cooldown(spell, action, spellMap, eventArgs)
        end
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('BLM', {
    load = ensure_modules_loaded,
    -- an ability with charges has no recast to check; a spell with lower tiers is re-tiered instead
    cooldown = check_recast_or_refine,
    after_cooldown = function(spell, action, spellMap, eventArgs)
        if spell.skill == 'Elemental Magic' and checkArts then
            checkArts(spell, eventArgs)
        end
    end,
})

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export global for GearSwap (Mote-Include)
_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

-- Module table for require() compatibility (parity with _G exports above)
return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}

