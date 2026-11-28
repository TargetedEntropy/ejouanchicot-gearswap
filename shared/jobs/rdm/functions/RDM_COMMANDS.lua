---  ═══════════════════════════════════════════════════════════════════════════
---   RDM Commands Module - Custom Command Handler
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles custom commands for Red Mage job via //gs c [command]:
---   dual-box, UI, watchdog and common commands first, then the RDM commands
---   (enspell, quick JAs, nukes and spells from states), then a cast-by-name
---   fallback for any JA / WS / spell name.
---   Also defines job_state_change (HUD refresh).
---
---   @file    shared/jobs/rdm/functions/RDM_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.1 - Refactored: removed code duplication + dead code
---   @date    Updated: 2025-11-12
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES
---  ═══════════════════════════════════════════════════════════════════════════

local JobCommands = require('shared/utils/core/job_commands')
-- a handler that returns PASS leaves the word unanswered (JobCommands.router)
local PASS = JobCommands.PASS

local MessageFormatter = require('shared/utils/messages/message_formatter')

-- Game resource tables searched by the cast-by-name fallback, in the order
-- a name is tried: ability, then weaponskill, then spell.
-- res.job_abilities also holds pet moves (prefix '/pet'), and 51 of them share
-- a spell's name (Fire II, Hastega, Sheep Song...), so only the player's own
-- abilities ('/jobability') count as a /ja.
local ACTION_RESOURCES = {
    {prefix = '/ja', resource = 'job_abilities', res_prefix = '/jobability'},
    {prefix = '/ws', resource = 'weapon_skills'},
    {prefix = '/ma', resource = 'spells'},
}

--- Command prefix that casts an action name, from the game resources.
--- @param action_name string Exact English name ("Refresh II", "Savage Blade")
--- @return string|nil '/ja', '/ws' or '/ma'; nil when no resource has the name
local function resolve_action_prefix(action_name)
    -- `res` is not a global in every job sandbox (GEO's escort crashed on it).
    local resources = rawget(_G, 'res') or windower.res or require('resources')
    if not resources then
        return nil
    end
    for _, entry in ipairs(ACTION_RESOURCES) do
        local resource = resources[entry.resource]
        local found = resource and resource:with('en', action_name)
        if found and (not entry.res_prefix or found.prefix == entry.res_prefix) then
            return entry.prefix
        end
    end
    return nil
end

--- Mote's command table. Its __index also answers the alt's commands
--- (AltCommands.install_fallback).
--- @return table|nil selfCommandMaps, nil before Mote has built it
local function mote_command_maps()
    local maps = rawget(_G, 'selfCommandMaps')
    return type(maps) == 'table' and maps or nil
end

---  ═══════════════════════════════════════════════════════════════════════════
---   HELPER TABLES (Reduce code duplication)
---  ═══════════════════════════════════════════════════════════════════════════

-- Quick JA commands (simple one-to-one mapping)
local quick_ja_commands = {
    convert = 'Convert',
    chainspell = 'Chainspell',
    saboteur = 'Saboteur',
    composure = 'Composure'
}

-- Cast spell from state (spell states with error handling)
local spell_state_commands = {
    castenspell = {
        state_name = 'EnSpell',
        target = '<me>',
        check_off = true,
        error_func = function() MessageFormatter.show_no_enspell_selected() end
    },
    castgain = {
        state_name = 'GainSpell',
        target = '<me>',
        error_func = function() MessageFormatter.show_gain_spell_not_configured() end
    },
    castbar = {
        state_name = 'Barspell',
        target = '<me>',
        error_func = function() MessageFormatter.show_bar_element_not_configured() end
    },
    castbarailment = {
        state_name = 'BarAilment',
        target = '<me>',
        error_func = function() MessageFormatter.show_bar_ailment_not_configured() end
    },
    castspike = {
        state_name = 'Spike',
        target = '<me>',
        error_func = function() MessageFormatter.show_spike_not_configured() end
    },
    caststorm = {
        state_name = 'Storm',
        target = '<me>',
        error_func = function() MessageFormatter.show_storm_requires_sch() end
    }
}

-- Nuke commands with tier (element + tier state combinations)
local nuke_commands = {
    castlight = {
        state_name = 'MainLightSpell',
        error_msg = 'Light spell states not configured'
    },
    castsublight = {
        state_name = 'SubLightSpell',
        error_msg = 'Sub Light spell states not configured'
    },
    castdark = {
        state_name = 'MainDarkSpell',
        error_msg = 'Dark spell states not configured'
    },
    castsubdark = {
        state_name = 'SubDarkSpell',
        error_msg = 'Sub Dark spell states not configured'
    }
}

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- //gs c enspell [element]: cast that element's enspell, or cycle state.EnSpell (silent)
local function enspell(cmdParams)

    if #cmdParams >= 2 then
        local element = cmdParams[2]:lower()
        local enspell_map = {
            fire = 'Enfire',
            blizzard = 'Enblizzard',
            ice = 'Enblizzard',
            aero = 'Enaero',
            wind = 'Enaero',
            stone = 'Enstone',
            earth = 'Enstone',
            thunder = 'Enthunder',
            water = 'Enwater'
        }

        local spell = enspell_map[element]
        if spell then
            send_command('input /ma "' .. spell .. '" <me>')
        else
            MessageFormatter.show_error('Unknown element: ' .. cmdParams[2])
            MessageFormatter.show_element_list()
        end
    else
        -- Cycle through enspell state (silent - no message needed)
        if state.EnSpell then
            state.EnSpell:cycle()
            -- Update UI manually (Mote doesn't trigger job_update for custom commands)
            if job_update then
                job_update()
            end
        end
    end
end

--- castlight / castsublight / castdark / castsubdark: the element state's nuke at state.NukeTier
local function nuke(_, command)
    local config = nuke_commands[command]
    local element_state = state[config.state_name]

    if element_state and state.NukeTier then
        local element = element_state.value
        local tier = state.NukeTier.value

        local spell_name = element
        if tier ~= 'I' then
            spell_name = element .. ' ' .. tier
        end

        send_command('input /ma "' .. spell_name .. '" <t>')
    else
        MessageFormatter.show_error(config.error_msg)
    end
end

--- castenspell / castgain / castbar / castbarailment / castspike / caststorm: the spell a state selects
local function spell_from_state(_, command)
    local config = spell_state_commands[command]
    local spell_state = state[config.state_name]

    if spell_state then
        -- Check if EnSpell is 'Off' (special case)
        if config.check_off and spell_state.value == 'Off' then
            config.error_func()
        else
            send_command('input /ma "' .. spell_state.value .. '" ' .. config.target)
        end
    else
        config.error_func()
    end
end

--- A word no table names: Mote's own commands, a spell that needs a piece in hand, else an action by its name.
local function other(cmdParams, command)
    -- Mote's own commands (update, cycle, set, naked...) are left unhandled:
    -- Mote runs them once job_self_command returns. rawget, because a plain
    -- lookup would also answer the alt's command names, and those must not
    -- get past the RDM commands.
    local mote_maps = mote_command_maps()
    if mote_maps and rawget(mote_maps, command) then
        return PASS
    end

    -- //gs c dispelga [target]: a spell that needs a piece in hand (Daybreak),
    -- cast through Combat Mode (spell_gear_lock.lua)
    if require('shared/utils/equipment/spell_gear_lock').cast(command, cmdParams[2]) then
        return
    end

    -- Cast by name: a spell bound without a command of its own
    -- ({ key = "^5", command = "Refresh II" } casts /ma "Refresh II" <me>, target below)
    -- Reconstruct full spell name from cmdParams (handles multi-word spells)
    local spell_name = table.concat(cmdParams, " ")

    if spell_name and spell_name ~= "" then
        -- Default target: <me> (self - avoids sub-target cursor)
        -- Can be overridden by adding target after spell name (e.g., <stpc>, <t>)
        local target = '<me>'

        -- Check if last parameter looks like a target (<me>, <t>, <stpc>, etc.)
        if #cmdParams >= 2 and cmdParams[#cmdParams]:match('^<.*>$') then
            target = cmdParams[#cmdParams]
            -- Rebuild spell name without target
            local spell_parts = {}
            for i = 1, #cmdParams - 1 do
                table.insert(spell_parts, cmdParams[i])
            end
            spell_name = table.concat(spell_parts, " ")
        end

        -- Auto-detect action type (JA, WS, or Magic)
        local action_type = resolve_action_prefix(spell_name)
        local ok_t, Trace = pcall(require, 'shared/utils/debug/trace_log')
        if ok_t and Trace then
            Trace.log('RDM', 'cast by name "%s" target %s -> %s (res global %s)', spell_name, target,
                action_type, rawget(_G, 'res') ~= nil)
        end

        if action_type then
            send_command('input ' .. action_type .. ' "' .. spell_name .. '" ' .. target)
        elseif mote_maps and mote_maps[cmdParams[1]] then
            -- Not an action but one of the alt's commands: left unhandled,
            -- Mote runs it through selfCommandMaps.
            return PASS
        else
            MessageFormatter.show_error(string.format("Command not recognized: '%s'", spell_name))
            MessageFormatter.show_info("Valid types: Job Abilities, Weaponskills, Magic Spells")
        end
        return
    end
    return PASS
end

local words = {
    enspell = enspell,
    -- Cycle Storm spell (SCH subjob only)
    cyclestorm = function()
        if state.Storm then
            state.Storm:cycle()
            MessageFormatter.show_storm_current(state.Storm.value)
        else
            MessageFormatter.show_storm_requires_sch()
        end
    end,
}
-- Quick JA commands (Convert, Chainspell, Saboteur, Composure)
for word, ability in pairs(quick_ja_commands) do
    words[word] = function()
        send_command('input /ja "' .. ability .. '" <me>')
    end
end
for word in pairs(nuke_commands) do words[word] = nuke end
for word in pairs(spell_state_commands) do words[word] = spell_from_state end

job_self_command = JobCommands.router('RDM', {words = words, other = other})

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HANDLER
---  ═══════════════════════════════════════════════════════════════════════════

---   Update UI when state changes
---   Called after state changes to update UI display. On cycle/set/toggle
---   commands the gear follows through handle_update, which Mote runs next.
---   @param stateField string The state key or description that changed
---   @param newValue any The new value
---   @param oldValue any The old value
function job_state_change(stateField, newValue, oldValue)
    -- Skip UI update for Moving state (handled by AutoMove with flag)
    if stateField == 'Moving' then
        return
    end

    -- Update UI display
    local ui_success, KeybindUI = pcall(require, 'shared/utils/ui/UI_MANAGER')
    if ui_success and KeybindUI then
        KeybindUI.update()
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export to global scope (used by Mote-Include via include())
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change
