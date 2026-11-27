---  ═══════════════════════════════════════════════════════════════════════════
---   RUN Precast Module - Precast Action Handling & Fast Cast
---  ═══════════════════════════════════════════════════════════════════════════
---   Debuff guard, cooldown check, WS handling.
---   Fast Cast set is chosen by Mote-Include (spell > skill > sets.precast.FC).
---
---   @file    shared/jobs/run/functions/RUN_PRECAST.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-05
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════

local MessagePrecast = nil

local modules_loaded = false

local function ensure_modules_loaded()
    if modules_loaded then return end

    local success, result

    success, result = pcall(require, 'shared/utils/messages/formatters/magic/message_precast')
    if success then MessagePrecast = result end

    modules_loaded = true
end

---   Self cure (Cure to Cure IV from the subjob): sets.precast.FC.CureSelf, a
---   Fast Cast set low on max HP. The midcast CureSelf set puts the HP back,
---   so the cure lands on a bigger HP gap (more healed, more enmity) - the
---   PLD setup. Runs in post_precast to replace Mote's FC set.
---   @param spell table Spell data
local function apply_cure_self_fc(spell)
    if not (spell.target and spell.target.type == 'SELF') then return end
    local fc = sets.precast and sets.precast.FC and sets.precast.FC.CureSelf
    if not fc then return end
    local ok, CureSetBuilder = pcall(require, 'shared/jobs/run/functions/logic/cure_set_builder')
    if ok and CureSetBuilder and CureSetBuilder.is_cure(spell) then
        equip(fc)
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('RUN', {
    load = ensure_modules_loaded,
    after_tp_gear = function(spell, action, spellMap, eventArgs)
        apply_cure_self_fc(spell)

        -- ══════════════════════════════════════════════════════════════════════════
        -- DEBUG: PRECAST SET DISPLAY (Universal System)
        -- ══════════════════════════════════════════════════════════════════════════
        -- Mote-Include already handles FC fallback: spell.name > spell.skill > base
        -- We just add debug display to show which set was selected
        if _G.PrecastDebugState and spell.action_type == 'Magic' then
            local selected_set = nil
            local set_name = 'sets.precast.FC'

            -- Detect which set Mote-Include selected
            if sets.precast.FC[spell.name] then
                selected_set = sets.precast.FC[spell.name]
                set_name = 'sets.precast.FC.' .. spell.name
            elseif spell.skill and sets.precast.FC[spell.skill] then
                selected_set = sets.precast.FC[spell.skill]
                set_name = 'sets.precast.FC[\'' .. spell.skill .. '\']'
            else
                selected_set = sets.precast.FC
                set_name = 'sets.precast.FC'
            end

            -- Show debug info
            MessagePrecast.show_debug_header(spell.name, spell.skill or 'Unknown')
            MessagePrecast.show_equipped_set(set_name)

            if selected_set then
                MessagePrecast.show_equipment(selected_set)
            end

            MessagePrecast.show_completion()
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
