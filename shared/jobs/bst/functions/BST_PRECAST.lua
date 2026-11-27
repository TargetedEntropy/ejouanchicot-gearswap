---  ═══════════════════════════════════════════════════════════════════════════
---   BST Precast Module - Precast Action Handling & Pet Commands
---  ═══════════════════════════════════════════════════════════════════════════
---   Debuff guard, cooldown check, WS handling, Call Beast/Bestial Loyalty,
---   Ready moves.
---
---   @file    shared/jobs/bst/functions/BST_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-05
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

-- Initialize BST debug flag if not exists
if _G.BST_DEBUG_PRECAST == nil then
    _G.BST_DEBUG_PRECAST = false  -- Toggle: //gs c debugprecast (BST_COMMANDS)
end

local MessageFormatter = nil
local MessagePrecast = nil  -- Debug formatter
local ReadyMoveCategorizer = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local mf_ok, mf = pcall(require, 'shared/utils/messages/message_formatter')
    if not mf_ok then mf = nil end
    MessageFormatter = mf

    local mp_ok, mp = pcall(require, 'shared/utils/messages/formatters/magic/message_precast')
    if not mp_ok then mp = nil end
    MessagePrecast = mp

    -- BST specific
    local rmc_ok, rmc = pcall(require, 'shared/jobs/bst/functions/logic/ready_move_categorizer')
    if not rmc_ok then rmc = nil end
    ReadyMoveCategorizer = rmc

    modules_loaded = true
end

--- Is this a pet Ready move, and which category?
---
--- 'Default' means the categoriser recognised nothing, which is not a Ready
--- move as far as this is concerned.
--- @return boolean is a ready move, string|nil category
local function ready_move_info(spell)
    if not (ReadyMoveCategorizer and spell.action_type == 'Ability') then
        return false, nil
    end

    local category = ReadyMoveCategorizer.get_category(spell.name)
    if category == nil or category == 'Default' then
        return false, nil
    end
    return true, category
end

--- Summon gear. The broth goes on in job_post_precast (equip_broth), after
--- Mote's default_precast has equipped the Call Beast / Bestial Loyalty set
--- again: an ammo in that set would otherwise replace the broth and summon
--- the wrong pet (or none).
local function equip_for_summon(spell)
    if _G.BST_DEBUG_PRECAST then
        MessagePrecast.show_debug_header(spell.name, 'Pet Summon')
    end

    if sets.precast.JA['Call Beast'] then
        equip(sets.precast.JA['Call Beast'])
        if _G.BST_DEBUG_PRECAST then
            MessagePrecast.show_equipped_set('precast.JA["Call Beast"]')
            MessagePrecast.show_equipment(sets.precast.JA['Call Beast'])
        end
    end
end

--- The broth of the pet chosen (state.ammoSet), last: it decides which pet
--- appears, so it wins over any ammo of the summon set.
local function equip_broth()
    if state.ammoSet and state.ammoSet.value and sets[state.ammoSet.value] then
        local broth_set = sets[state.ammoSet.value]
        if broth_set and broth_set.ammo then
            equip({ammo = broth_set.ammo})
            if _G.BST_DEBUG_PRECAST then
                MessagePrecast.show_debug_step(1, 'Broth Override', 'ok', broth_set.ammo)
            end
        end
    end

    if _G.BST_DEBUG_PRECAST then
        MessagePrecast.show_completion()
    end
end

--- Mark the move for midcast and put the precast piece on.
---
--- The category is carried on the spell (the same object reaches midcast) so
--- midcast does not have to work it out again from the name.
local function prepare_ready_move(spell, category)
    spell.ready_move_category = category
    spell.bst_is_ready_move = true
    if sets.precast.JA['Sic'] then
        equip(sets.precast.JA['Sic'])
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('BST', {
    load = ensure_modules_loaded,
    -- Ready moves (type 'Monster') spend charges. Their recast (id 102) is the
    -- charge timer, which runs while charges remain, so a cooldown check would
    -- refuse a move the game allows; the game refuses it itself at 0 charges.
    cooldown = function(spell, eventArgs)
        if spell.type ~= 'Monster' then
            PrecastPipeline.cooldown(spell, eventArgs)
        end
    end,
    after_ws = function(spell)
        if spell.name == 'Call Beast' or spell.name == 'Bestial Loyalty' then
            equip_for_summon(spell)
            return
        end
        local is_ready_move, ready_move_category = ready_move_info(spell)
        if is_ready_move then
            prepare_ready_move(spell, ready_move_category)
        end
    end,
    before_tp_gear = function(spell)
        if spell.name == 'Call Beast' or spell.name == 'Bestial Loyalty' then
            equip_broth()
            return true
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

