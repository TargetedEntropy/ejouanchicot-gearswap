---  ═══════════════════════════════════════════════════════════════════════════
---   GEO Precast Module - Precast Action Handling & Cooldown Monitoring
---  ═══════════════════════════════════════════════════════════════════════════
---   Precast hook for Geomancer. Precast gear itself (Fast Cast, JA sets) is
---   chosen by Mote from sets.precast; this module adds:
---   • PrecastGuard (debuffs) then CooldownChecker (abilities and spells);
---     nukes, -ra and Aspir cast from a macro drop to the highest ready tier
---     instead (TierRefiner, shared/data/spells/NUKE_TIERS.lua)
---   • Entrust pending flag (read by GEO_MIDCAST before the buff appears)
---   • WSPrecastHandler for weaponskills and TP bonus gear
---
---   @file    shared/jobs/geo/functions/GEO_PRECAST.lua
---   @author  ejouanchicot
---   @version 2.0
---   @date    Created: 2025-10-09
---   @requires Tetsouo architecture, MessageFormatter, CooldownChecker
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

-- A Geo- aimed at a monster lands behind it when geo/combat/GEO_CONFIG.lua sets luopan_behind
-- (shared/jobs/geo/functions/logic/luopan_behind.lua): its packet listener, once per load
pcall(function() require('shared/jobs/geo/functions/logic/luopan_behind').listen() end)
-- Stun / Absorb-TP told in party chat when geo/combat/GEO_CONFIG.lua lists them in party_callouts
-- (shared/utils/messages/party_callouts.lua): its action listener, once per load
pcall(function() require('shared/utils/messages/party_callouts').listen('GEO') end)
-- //gs c behind on before this load goes on (shared/jobs/geo/functions/logic/stand_behind.lua)
pcall(function() require('shared/jobs/geo/functions/logic/stand_behind').resume() end)

local TierRefiner = nil
local NukeTiers = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local tr_ok, tr = pcall(require, 'shared/utils/precast/tier_refiner')
    TierRefiner = tr_ok and tr or nil
    local nuke_ok, nukes = pcall(require, 'shared/data/spells/NUKE_TIERS')
    NukeTiers = nuke_ok and nukes or nil

    modules_loaded = true
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('GEO', {
    load = ensure_modules_loaded,
    -- Tiered nukes go through the refiner instead of the cooldown check:
    -- the checker would cancel the cast before any downgrade could happen.
    cooldown = function(spell, eventArgs)
        local tiers = spell.action_type == 'Magic' and TierRefiner and NukeTiers
            and NukeTiers.get(spell.name and spell.name:match('^(%a+)'))
        if tiers then
            TierRefiner.refine(spell, eventArgs, tiers)
        else
            PrecastPipeline.cooldown(spell, eventArgs)
        end
    end,
    after_cooldown = function(spell, eventArgs)
        -- One of our queued abilities just went: the bot's spell is held back 1.5 s so it does not cut it, never Stun
        -- (shared/utils/precast/ability_queue.lua). Under pcall: an error in the queue lets the spell go, never blocks it
        local ok_q, held = pcall(function() return require('shared/utils/precast/ability_queue').hold_check(spell, eventArgs) end)
        if ok_q and held then
            return true
        end
        -- Running to the spot behind the monster: the bot's spell waits until she stands, never Stun (stand_behind.lua)
        local ok_b, held_b = pcall(function()
            return require('shared/jobs/geo/functions/logic/stand_behind').hold_check(spell, eventArgs)
        end)
        if ok_b and held_b then
            return true
        end

        -- Entrust / Full Circle first, when the character turned them on
        -- (geo/combat/GEO_CONFIG.lua)
        require('shared/jobs/geo/functions/logic/geo_auto_abilities').apply(spell, eventArgs)
        if eventArgs.cancel or eventArgs.handled then
            return true
        end
        -- A Geo- while a luopan is out, with luopan_behind on: the game would refuse it (luopan_behind.lua)
        if require('shared/jobs/geo/functions/logic/luopan_behind').skip_while_out(spell, eventArgs) then
            return true
        end
        require('shared/jobs/geo/functions/logic/bolster_follow').note_cast(spell)

        -- Raised optimistically: aftercast lowers it again if Entrust is interrupted
        if spell.type == 'JobAbility' and spell.name == 'Entrust' then
            _G.geo_entrust_pending = true
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

