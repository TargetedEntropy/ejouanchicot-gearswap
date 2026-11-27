---  ═══════════════════════════════════════════════════════════════════════════
---   DNC Precast Module - Precast Action Handling & Cooldown Monitoring
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles all precast actions for Dancer:
---   • Mote refine_waltz override (waltzes are never re-tiered or blocked)
---   • Samba TP cost check (cancels a Samba the player cannot pay for)
---   • Climactic Flourish timestamp (read by ws_variant_selector)
---   • Auto-Jump before WS on /DRG (auto_jump.lua, run by WSPrecastHandler)
---   • Auto-Climactic Flourish before configured WS (logic/climactic_manager)
---   • WS variant from dance/Climactic buffs, then TP bonus gear (post-precast)
---
---   job_precast order (do not reorder):
---   1. Debuff guard (PrecastGuard)
---   2. Cooldown check (CooldownChecker; Utsusemi excluded)
---   3. Samba TP cost, Climactic timestamp
---   4. WS only: WSPrecastHandler.handle (range, Auto-Jump on /DRG, TP),
---      Auto-Climactic (needs 1000 TP). Jump and Climactic may cancel and
---      replay the WS.
---
---   @file    shared/jobs/dnc/functions/DNC_PRECAST.lua
---   @author  ejouanchicot
---   @version 3.2
---   @date    Created: 2025-10-04 | Updated: 2025-10-10
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

local MessageFormatter = nil
local ClimaticManager = nil
local WSVariantSelector = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local mf_ok, mf = pcall(require, 'shared/utils/messages/message_formatter')
    if not mf_ok then mf = nil end
    MessageFormatter = mf

    -- DNC logic modules
    local cm_ok, cm = pcall(require, 'shared/jobs/dnc/functions/logic/climactic_manager')
    if not cm_ok then cm = nil end
    ClimaticManager = cm
    local wsv_ok, wsv = pcall(require, 'shared/jobs/dnc/functions/logic/ws_variant_selector')
    if not wsv_ok then wsv = nil end
    WSVariantSelector = wsv

    modules_loaded = true
end

---  ═══════════════════════════════════════════════════════════════════════════
---   MOTE OVERRIDES
---  ═══════════════════════════════════════════════════════════════════════════

---   Override Mote's refine_waltz with a no-op, so a waltz is never blocked on
---   a full-HP target (wake-up utility: removing sleep from party members).
---   Tier selection is done by WaltzManager through //gs c waltz / aoewaltz.
---   @param spell table Spell information from GearSwap
---   @param action string Action type
---   @param spellMap string Spell mapping from Mote-Include
---   @param eventArgs table Event arguments
function refine_waltz(spell, action, spellMap, eventArgs)
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST STEPS
---  ═══════════════════════════════════════════════════════════════════════════

--- Cancel a Samba the player cannot pay for, before it reaches the server.
--- Each Samba has its own cost (Drain 100, Drain II 250, Haste 350, Drain III
--- 400), read from the resource line GearSwap puts on the spell.
--- Trance makes dances free (shared/data/job_abilities/dnc/dnc_sp.lua).
--- @param spell table Spell information from GearSwap
--- @param eventArgs table Event args (eventArgs.cancel for cancellation)
local function job_precast_samba(spell, eventArgs)
    if buffactive['Trance'] then
        return
    end

    local cost = spell.tp_cost or 0
    local current_tp = require('shared/utils/core/live_tp')()
    if current_tp < cost then
        MessageFormatter.show_ability_tp_error(spell.name, current_tp, cost)
        eventArgs.cancel = true
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('DNC', {
    load = ensure_modules_loaded,
    -- Cooldown check, Utsusemi excluded
    cooldown = function(spell, eventArgs)
        if spell.action_type == 'Magic' and (spell.english == 'Utsusemi: Ni' or spell.english == 'Utsusemi: Ichi') then
            return
        end
        PrecastPipeline.cooldown(spell, eventArgs)
    end,
    after_cooldown = function(spell, eventArgs)
        if spell.type == 'Samba' and MessageFormatter then
            job_precast_samba(spell, eventArgs)
        end
        if spell.type == 'Flourish3' and spell.english == 'Climactic Flourish' then
            _G.dnc_climactic_timestamp = os.time()
        end
    end,
    after_ws = function(spell, eventArgs)
        if spell.type == 'WeaponSkill' and ClimaticManager then
            ClimaticManager.auto_trigger(spell, eventArgs)
        end
    end,
    before_tp_gear = function(spell, action, spellMap, eventArgs)
        if spell.type == 'WeaponSkill' then
            -- DNC-SPECIFIC: Apply WS set variant based on buffs (Fan Dance/Climactic)
            -- MUST happen BEFORE TP bonus gear to avoid overwriting Moonshade
            if WSVariantSelector then
                WSVariantSelector.apply_variant(spell)
            end
        end
    end,
})

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export to global scope (used by Mote-Include via include())
_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

-- Module table for require() compatibility (parity with _G exports above)
return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}

