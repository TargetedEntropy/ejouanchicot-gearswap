---  ═══════════════════════════════════════════════════════════════════════════
---   WHM Precast Module - Precast Action Handling & Cooldown Monitoring
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles all precast actions for White Mage job:
---   • Cure re-tiering by the target's need (CureManager)
---   • Paralyna while paralyzed: no precast set (the midcast set still goes on)
---   • Weaponskill validation and range checking
---   Fast Cast and job ability sets are left to Mote-Include.
---
---   Processing order:
---   1. PrecastGuard - Block casting under debuffs (Amnesia, Silence, Stun, etc.)
---   2. CureManager re-tier (before the cooldown check, see job_precast)
---   3. CooldownChecker - Universal ability/spell recast validation
---   4. Paralyna on self
---   5. WSPrecastHandler - Weaponskill range, validity and TP checks
---
---   @file    shared/jobs/whm/functions/WHM_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0.0
---   @date    Created: 2025-10-21
---   @requires shared/utils/messages/message_formatter, shared/utils/precast/cooldown_checker
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

local CureManager = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local cm_ok, cm = pcall(require, 'shared/utils/whm/cure_manager')
    if not cm_ok then cm = nil end
    CureManager = cm

    modules_loaded = true
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST STEPS
---  ═══════════════════════════════════════════════════════════════════════════

--- Curing your own paralysis: no precast set.
---
--- Paralysis blocks the spell, never the equipment change - so this is not
--- about protecting the cast. It is about the blinking: a paralyzed Paralyna
--- is retried until it lands, and each attempt swaps sets on and off again.
--- (Timara WHM pattern.) Only the precast swap is saved: eventArgs.handled
--- here skips Mote's default precast, but the midcast is another event with
--- its own eventArgs, and job_post_midcast still puts on the StatusRemoval /
--- Paralyna set. The target is not checked.
--- @param spell table Spell data from GearSwap
--- @param eventArgs table Event arguments (handled is set when it applies)
--- @return boolean True when this case applies
local function paralyna_on_self(spell, eventArgs)
    if spell.english == 'Paralyna' and buffactive['paralysis'] then
        eventArgs.handled = true
        return true
    end
    return false
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('WHM', {
    load = ensure_modules_loaded,
    -- Cures are re-tiered before the recast check: the checker would cancel
    -- a tier on recast before CureManager could swap it for a ready one.
    -- A cure left as it is still goes through the check below.
    before_cooldown = function(spell, action, spellMap, eventArgs)
        return CureManager and CureManager.retier(spell, eventArgs)
    end,
    after_cooldown = function(spell, action, spellMap, eventArgs)
        return paralyna_on_self(spell, eventArgs)
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
