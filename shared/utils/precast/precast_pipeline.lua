---============================================================================
--- Precast Pipeline - every job's job_precast / job_post_precast in one order
---============================================================================
--- The steps every <JOB>_PRECAST.lua used to write out for itself, in the
--- order that matters:
---
---   job_precast
---     1. PrecastGuard          blocked by a debuff (Amnesia, Silence...): stop
---     2. before_cooldown       a job's step that may replace the action (a song or a Cure re-tiered,
---                              Double-Up redirected): true stops
---     3. cooldown              CooldownChecker on abilities and spells (a job may give its own: a spell
---                              re-tiered instead, charges, Utsusemi)
---        eventArgs.cancel      stop
---     4. after_cooldown        the job's own steps: true stops
---     5. WSPrecastHandler      a weaponskill's range, validity, auto-Jump, TP and TP pieces: false stops
---     6. after_ws              the job's steps once the action is going ahead
---
---   job_post_precast
---     1. before_tp_gear        true: the TP pieces are not put on
---     2. WSPrecastHandler.apply_tp_gear
---     3. after_tp_gear
---
--- A job's TP configuration is _G.<JOB>TPConfig (set by its entry file), read
--- at its first action.
---
---   job_precast, job_post_precast = PrecastPipeline.hooks('SAM', {
---       after_cooldown = function(spell, action, spellMap, eventArgs) ... end,
---   })
---
--- @file    shared/utils/precast/precast_pipeline.lua
---============================================================================
local PrecastPipeline = {}

local PrecastGuard, CooldownChecker, WSPrecastHandler

local function load()
    if PrecastGuard then return end
    PrecastGuard = require('shared/utils/debuff/precast_guard')
    CooldownChecker = require('shared/utils/precast/cooldown_checker')
    WSPrecastHandler = require('shared/utils/precast/ws_precast_handler')
end

--- The recast check of an ability or a spell (anything else has none): the default cooldown step.
function PrecastPipeline.cooldown(spell, action, spellMap, eventArgs)
    load()
    if spell.action_type == 'Ability' then
        CooldownChecker.check_ability_cooldown(spell, eventArgs)
    elseif spell.action_type == 'Magic' then
        CooldownChecker.check_spell_cooldown(spell, eventArgs)
    end
end

--- One kind of recast check, for a job that chooses which applies (BLM's charges, SCH's tiers).
function PrecastPipeline.ability_cooldown(spell, action, spellMap, eventArgs)
    load()
    CooldownChecker.check_ability_cooldown(spell, eventArgs)
end

function PrecastPipeline.spell_cooldown(spell, action, spellMap, eventArgs)
    load()
    CooldownChecker.check_spell_cooldown(spell, eventArgs)
end

--- job_precast and job_post_precast for a job. Every step gets Mote's four arguments,
--- (spell, action, spellMap, eventArgs).
--- @param job string The job's code ('WAR'): its TP configuration is _G.<job>TPConfig
--- @param steps table|nil Its own steps: before_cooldown, cooldown, after_cooldown, after_ws, before_tp_gear,
---        after_tp_gear (see the header); cooldown replaces PrecastPipeline.cooldown; load() runs first in both
---        hooks (the job's own modules, loaded at its first action)
--- @return function job_precast, function job_post_precast
function PrecastPipeline.hooks(job, steps)
    steps = steps or {}
    local cooldown = steps.cooldown or PrecastPipeline.cooldown
    local tp_config

    -- the shared modules, the job's own, its TP configuration
    local function prepare()
        load()
        if steps.load then steps.load() end
        tp_config = tp_config or _G[job .. 'TPConfig'] or {}
    end

    local function job_precast(spell, action, spellMap, eventArgs)
        prepare()
        if PrecastGuard.guard_precast(spell, eventArgs) then return end
        if steps.before_cooldown and steps.before_cooldown(spell, action, spellMap, eventArgs) then return end
        cooldown(spell, action, spellMap, eventArgs)
        if eventArgs.cancel then return end
        if steps.after_cooldown and steps.after_cooldown(spell, action, spellMap, eventArgs) then return end
        if not WSPrecastHandler.handle(spell, eventArgs, tp_config) then return end
        if steps.after_ws then steps.after_ws(spell, action, spellMap, eventArgs) end
    end

    local function job_post_precast(spell, action, spellMap, eventArgs)
        prepare()
        if steps.before_tp_gear and steps.before_tp_gear(spell, action, spellMap, eventArgs) then return end
        WSPrecastHandler.apply_tp_gear(spell)
        if steps.after_tp_gear then steps.after_tp_gear(spell, action, spellMap, eventArgs) end
    end

    return job_precast, job_post_precast
end

return PrecastPipeline
