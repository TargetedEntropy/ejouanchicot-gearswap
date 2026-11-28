---  ═══════════════════════════════════════════════════════════════════════════
---   BLM Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Black Mage job:
---   • BLM element cycling (MainLight, MainDark, SubLight, SubDark)
---   • BLM spell cycling (Storm)
---   • BLM-specific commands (buff, storm, klima, dispel, light/dark/aoe nukes);
---     lightarts, darkarts and aoe sneak/invi are common commands
---   • CombatMode weapon lock (job_state_change)
---   • State change UI synchronization with colored element messages
---
---   The words every job shares go through JobCommands.router (shared/utils/core/job_commands.lua).
---   Movement gear handled passively via customize_idle_set() like other jobs.
---
---   @file    shared/jobs/blm/functions/BLM_COMMANDS.lua
---   @author  ejouanchicot
---   @version 2.3.0 - Added party Sneak/Invi commands (Accession automation)
---   @date    Created: 2025-10-15 | Updated: 2025-10-17
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES
---  ═══════════════════════════════════════════════════════════════════════════
local JobCommands = require('shared/utils/core/job_commands')
-- a handler that returns PASS leaves the word unanswered (JobCommands.router)
local PASS = JobCommands.PASS

local MessageFormatter = require('shared/utils/messages/message_formatter')
-- BLM message formatter (handles all colored messages)
local BLMMessages = require('shared/utils/messages/formatters/jobs/message_blm')
local StratagemCharges = require('shared/utils/scholar/stratagem_charges')
local ScholarActions = require('shared/utils/scholar/scholar_actions')

--- Dark Arts has its own recast slot and costs no stratagem charge.
local DARK_ARTS_RECAST_ID = 232

---   Build a single-target nuke name ('Fire' + 'V' -> 'Fire V')
---   Tier I casts the base spell, which carries no numeral.
---   @param element string Element name from the spell state
---   @param tier string    Tier from state.SpellTier
---   @return string Spell name
local function build_nuke_name(element, tier)
    return element .. ((tier ~= 'I') and (' ' .. tier) or '')
end

---   Build an AOE nuke name ('Firaga' + 'III' -> 'Firaga III')
---   Tier 'Aja' swaps the -ga family for its -ja counterpart (Firaga -> Firaja).
---   @param element string -ga spell name from the AOE state
---   @param tier string    Tier from state.AOETier
---   @return string Spell name
local function build_aoe_name(element, tier)
    if tier == 'Aja' then
        return element:match('(%a+)ga') .. 'ja'
    end

    return build_nuke_name(element, tier)
end

---   Cast the spell described by an element state and a tier state
---   @param element_state table Mote state holding the element
---   @param tier_state table    Mote state holding the tier
---   @param builder function    build_nuke_name or build_aoe_name
---   @return boolean True when the cast was issued
local function cast_from_states(element_state, tier_state, builder)
    if not (element_state and tier_state) then
        return false
    end

    windower.chat.input('/ma "' .. builder(element_state.current, tier_state.current) .. '" <stnpc>')

    return true
end

---   Refresh the keybind UI after a state change
local function update_ui()
    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        KeybindUI.update()
    end
end

-- NOTE: BLM logic functions are loaded globally via blm_functions.lua:
--   • BuffSelf() - the common //gs c buff (shared/utils/buffs/buff_command.lua)
--   • CastStorm() - Storm + Klimaform automation
--   • refine_various_spells() - Spell refinement (tier downgrading)
-- These functions are available in _G scope and called directly

---  ═══════════════════════════════════════════════════════════════════════════
---   BLM CYCLE COMMAND HANDLERS
---  ═══════════════════════════════════════════════════════════════════════════

--- cyclemainlight / cyclemaindark / cyclesublight / cyclesubdark: the element state, its label in the message.
local ELEMENT_CYCLES = {
    cyclemainlight = {'MainLightSpell', 'MainLight'},   -- Fire/Thunder/Aero
    cyclemaindark = {'MainDarkSpell', 'MainDark'},      -- Stone/Blizzard/Water
    cyclesublight = {'SubLightSpell', 'SubLight'},      -- Thunder/Fire/Aero
    cyclesubdark = {'SubDarkSpell', 'SubDark'},         -- Blizzard/Stone/Water
}

--- Cycle an element state, with its coloured message.
local function cycle_element(_, command)
    local name, label = unpack(ELEMENT_CYCLES[command])
    local element = state and state[name]
    if not element then return PASS end
    element:cycle()
    BLMMessages.show_element_cycle(label, element.value)
    update_ui()
end

--- //gs c cycle Storm, with its coloured message (any other cycle is left to Mote).
local function cycle_storm(cmdParams)
    if not (cmdParams[1] == 'cycle' and cmdParams[2] == 'Storm' and state and state.Storm) then return PASS end
    state.Storm:cycle()
    BLMMessages.show_storm_cycle(state.Storm.value)
    update_ui()
end

--- light / dark / sublight / subdark: a single-target nuke (element state + SpellTier); aoelight / aoedark /
--- subaoelight / subaoedark: an AOE nuke (-ga element state + AOETier: Aja >> III >> II >> I).
local NUKES = {
    light = {'MainLightSpell', 'SpellTier', build_nuke_name},
    dark = {'MainDarkSpell', 'SpellTier', build_nuke_name},
    sublight = {'SubLightSpell', 'SpellTier', build_nuke_name},
    subdark = {'SubDarkSpell', 'SpellTier', build_nuke_name},
    aoelight = {'MainLightAOE', 'AOETier', build_aoe_name},
    aoedark = {'MainDarkAOE', 'AOETier', build_aoe_name},
    subaoelight = {'SubLightAOE', 'AOETier', build_aoe_name},
    subaoedark = {'SubDarkAOE', 'AOETier', build_aoe_name},
}

local function nuke(_, command)
    local element, tier, builder = unpack(NUKES[command])
    if not cast_from_states(state[element], state[tier], builder) then return PASS end
end

--- Klima: Dark Arts + Manifestation + Klimaform, each step only when usable.
--- Klimaform itself always fires; the two stratagem steps are opportunistic.
local function klima(_, command)
    local steps = {}

    local dark_active = buffactive and (buffactive['Dark Arts'] or buffactive['Addendum: Black'])
    local dark_recast = windower.ffxi.get_ability_recasts()[DARK_ARTS_RECAST_ID] or 0

    if not dark_active and is_recast_ready(dark_recast) then
        table.insert(steps, {command = 'input /ja "Dark Arts" <me>', buff = 'Dark Arts'})
    end

    if ScholarActions.is_on(state.KlimaformAOE) then
        if StratagemCharges.has_charge() then
            table.insert(steps, {command = 'input /ja "Manifestation" <me>', buff = 'Manifestation'})
        else
            ScholarActions.warn_no_charge('Manifestation')
        end
    end

    -- Each step waits on its own buff instead of a fixed `wait 2`: an
    -- ability sent while the previous one still holds the action lock is
    -- refused, and the old chain never noticed. finish_anyway because
    -- Klimaform is worth casting even when Manifestation did not land -
    -- it is simply single-target then.
    ScholarActions.run_chain(steps, function()
        send_command('input /ma "Klimaform" <me>')
    end, true)

end

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- BLM's words (buff / buffs / buffself / selfbuff are the common command: shared/utils/buffs/buff_command.lua,
--- BLM's list in BUFF_CONFIG.lua `job`):
---   cyclemainlight / cyclemaindark / cyclesublight / cyclesubdark, cycle Storm   the states, with coloured messages
---   klima            Dark Arts + Manifestation + Klimaform (charge-aware)
---   dispel           Dispel via /RDM, or via Addendum: Black on /SCH
---   storm            Current Storm state, with Klimaform (CastStorm)
---   light / dark / sublight / subdark, aoelight / aoedark / subaoelight / subaoedark   the nukes (NUKES)
local words = {
    cycle = cycle_storm,
    klima = klima,
    klimaform = klima,
    -- Dispel: BLM only has access via /RDM, or via /SCH with Addendum: Black.
    -- /RDM      : direct cast on <stnpc>
    -- /SCH path : Addendum: Black is REQUIRED (Dark Arts alone doesn't grant Dispel)
    --   Addendum: Black active                    -> cast Dispel directly
    --   Dark Arts active, no Addendum: Black     -> Addendum: Black, then Dispel
    --   Nothing active                            -> Dark Arts, Addendum: Black, then Dispel
    -- FFXI rejects intermediate JAs if no stratagem charge is available.
    dispel = function()
        local sub = (player and player.sub_job) or 'NON'
        if sub == 'RDM' then
            send_command('input /ma "Dispel" <stnpc>')
        elseif sub == 'SCH' then
            ScholarActions.cast_under_black_addendum('Dispel', '<stnpc>')
        else
            local MessageCore = require('shared/utils/messages/message_core')
            MessageCore.warning(('Dispel unavailable on BLM/%s. Need /RDM or /SCH.'):format(sub))
        end
    end,
    -- Storm: Cast current storm spell with automatic Klimaform (for SCH subjob)
    storm = function()
        if not (state and state.Storm) then return PASS end
        local storm_name = state.Storm.current
        -- Function loaded globally via blm_functions.lua
        if CastStorm then
            CastStorm(storm_name)
        else
            -- Fallback: cast Storm without Klimaform check
            send_command('input /ma "' .. storm_name .. '" <me>')
        end
    end,
}
for word in pairs(ELEMENT_CYCLES) do words[word] = cycle_element end
for word in pairs(NUKES) do words[word] = nuke end

job_self_command = JobCommands.router('BLM', {words = words})

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   Update UI when state changes (MainWeapon, HybridMode, etc.) and put the
---   magic weapons on when Combat Mode turns On (the lock itself is
---   shared/utils/core/combat_mode.lua's).
---   Called by Mote-Include after any state change.
---
---   @param stateField string State that changed (e.g., "MainWeapon")
---   @param newValue   string New value
---   @param oldValue   string Previous value
---   @return void
function job_state_change(stateField, newValue, oldValue)
    -- DEBUG: Track which state triggered this
    if _G.AUTOMOVE_DEBUG then
        MessageFormatter.show_debug('BLM', string.format('[job_state_change] state=%s, old=%s, new=%s',
            tostring(stateField), tostring(oldValue), tostring(newValue)))
    end

    -- Skip UI update for Moving state (handled by AutoMove with flag)
    if stateField == 'Moving' then
        if _G.AUTOMOVE_DEBUG then
            MessageFormatter.show_debug('BLM', '[job_state_change] SKIPPED (Moving state)')
        end
        return
    end

    -- Combat Mode On puts on sets.CombatMode (the set file's) before its
    -- lock: shared/utils/core/combat_mode.lua.

    update_ui()
end

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export globally for GearSwap
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

