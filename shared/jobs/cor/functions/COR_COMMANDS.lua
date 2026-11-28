---  ═══════════════════════════════════════════════════════════════════════════
---   COR Commands Module - Custom Command Handler
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles custom commands for Corsair job via //gs c [command].
---   Provides job-specific commands and integrates with common commands.
---
---   COR commands: track_roll <short> <value>, rolls, doubleup (du),
---   clearrolls, party, clearparty, shot / roll1 / roll2 (ability selected in
---   QuickDraw / MainRoll / SubRoll). testcolors / colors are common commands.
---   job_state_change re-equips gear when MainWeapon / RangeWeapon changes.
---
---   @file    shared/jobs/cor/functions/COR_COMMANDS.lua
---   @author  ejouanchicot
---   @version 1.1
---   @date    Created: 2025-10-07
---   @date    Updated: 2025-10-10
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════
local MessageFormatter = nil
local RollTracker = nil

local function ensure_commands_loaded()
    if not MessageFormatter then
        MessageFormatter = require('shared/utils/messages/message_formatter')
        local ok, tracker = pcall(require, 'shared/jobs/cor/functions/logic/roll_tracker')
        RollTracker = ok and tracker or nil
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   SELECTED ABILITY COMMANDS
---  ═══════════════════════════════════════════════════════════════════════════

-- Commands that use the ability selected in a state: the state value plus the
-- suffix is the ability name ('Light' -> 'Light Shot', 'Chaos Roll' as is).
local SELECTED_ABILITY_COMMANDS = {
    shot  = { state = 'QuickDraw', suffix = ' Shot', target = '<t>' },
    roll1 = { state = 'MainRoll',  suffix = '',      target = '<me>' },
    roll2 = { state = 'SubRoll',   suffix = '',      target = '<me>' },
}

--- Use the ability selected in a state. Sent as a normal /ja, so it goes
--- through precast like a macro would (debuff guard, recast check, gear).
--- @param entry table One SELECTED_ABILITY_COMMANDS entry
--- @return void
local function use_selected_ability(entry)
    local selection = state[entry.state]
    if not selection then
        MessageFormatter.show_error(entry.state .. ' state is not configured')
        return
    end

    send_command(string.format('input /ja "%s%s" %s', selection.value, entry.suffix, entry.target))
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

-- track_roll's short names for the rolls
local ROLL_SHORTCUTS = {
    chaos = "Chaos Roll",
    sam = "Samurai Roll",
    samurai = "Samurai Roll",
    hunters = "Hunter's Roll",
    hunter = "Hunter's Roll",
    tactician = "Tactician's Roll",
    tact = "Tactician's Roll",
    allies = "Allies' Roll",
    wizard = "Wizard's Roll",
    wiz = "Wizard's Roll",
    warlock = "Warlock's Roll",
    lock = "Warlock's Roll",
    corsair = "Corsair's Roll",
    cor = "Corsair's Roll",
    caster = "Caster's Roll",
    cast = "Caster's Roll",
    courser = "Courser's Roll",
    course = "Courser's Roll",
    blitzer = "Blitzer's Roll",
    blitz = "Blitzer's Roll",
    fighter = "Fighter's Roll",
    fight = "Fighter's Roll",
    rogue = "Rogue's Roll",
    gallant = "Gallant's Roll",
    gal = "Gallant's Roll",
    evoker = "Evoker's Roll",
    evo = "Evoker's Roll",
    bolter = "Bolter's Roll",
    bolt = "Bolter's Roll",
    miser = "Miser's Roll",
    companion = "Companion's Roll",
    comp = "Companion's Roll",
    avenger = "Avenger's Roll",
    ave = "Avenger's Roll",
    naturalist = "Naturalist's Roll",
    nat = "Naturalist's Roll"
}

--- A roll word, only run when the roll tracker loaded (answered either way).
local function with_tracker(fn)
    return function(cmdParams)
        if not RollTracker then
            MessageFormatter.show_error('RollTracker not loaded')
            return
        end
        fn(cmdParams)
    end
end

--- Manual roll tracking (for testing or when auto-detect fails): //gs c track_roll chaos 7
local track_roll = with_tracker(function(cmdParams)
    if #cmdParams < 3 then
    MessageFormatter.show_error('Usage: //gs c track_roll <roll_short_name> <value>')
    MessageFormatter.show_info('Examples: chaos, sam, hunters, tactician, allies')
    return
    end
    local roll_name = ROLL_SHORTCUTS[cmdParams[2]:lower()]
    if not roll_name then
    MessageFormatter.show_error('Unknown roll shortcut: ' .. cmdParams[2])
    MessageFormatter.show_info('Use: chaos, sam, hunters, tactician, allies, etc.')
    return
    end
    local roll_value = tonumber(cmdParams[3])
    if not roll_value or roll_value < 1 or roll_value > 12 then
    MessageFormatter.show_invalid_roll_value(roll_value or 0)
    return
    end
    RollTracker.on_roll_cast(roll_name, roll_value)
end)

-- the Double-Up window
local double_up = with_tracker(function() RollTracker.display_double_up_status() end)

local function selected_ability(_, command)
    use_selected_ability(SELECTED_ABILITY_COMMANDS[command])
end

job_self_command = JobCommands.router('COR', {
    load = ensure_commands_loaded,
    words = {
    track_roll = track_roll,
    trackroll = track_roll,
    rolls = with_tracker(function()
        -- After a reload the list is empty although rolls may be up
        if RollTracker.sync_with_buffs then RollTracker.sync_with_buffs() end
        if _G.cor_active_rolls and #_G.cor_active_rolls > 0 then
            MessageFormatter.show_active_rolls(_G.cor_active_rolls)
        else
            MessageFormatter.show_info('No active rolls')
        end
    end),
    doubleup = double_up,
    du = double_up,
    clearrolls = with_tracker(function()
        RollTracker.clear_all()
        MessageFormatter.show_rolls_cleared()
    end),
    -- Compare the roll gear sent with the gear worn when the roll goes off
    rolldebug = function()
        local on = require('shared/jobs/cor/functions/logic/roll_debug').toggle()
        MessageFormatter.show_info('Roll debug: ' .. (on and 'ON' or 'OFF'))
    end,
    -- The party members detected and their jobs
    party = function()
        local pt_ok, PartyTracker = pcall(require, 'shared/jobs/cor/functions/logic/party_tracker')
        MessageFormatter.show_party_members(pt_ok and PartyTracker and PartyTracker.members_for_display() or {})
    end,
    -- Clear the party job cache (a member changed job)
    clearparty = function()
        if _G.cor_party_jobs then
            for k in pairs(_G.cor_party_jobs) do _G.cor_party_jobs[k] = nil end
            MessageFormatter.show_info('Party job cache cleared - will refresh automatically')
        else
            MessageFormatter.show_error('Party tracking not initialized')
        end
    end,
    -- shot / roll1 / roll2: the ability selected in QuickDraw / MainRoll / SubRoll
    shot = selected_ability,
    roll1 = selected_ability,
    roll2 = selected_ability,
    },
})

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

local LifecycleManager = require('shared/utils/core/lifecycle_manager')

-- Weapon states whose change re-equips gear
local WEAPON_STATES = { MainWeapon = true, RangeWeapon = true }

--- Re-equip when a weapon state changes.
---
--- The field is compared with spaces stripped, so the state key ('MainWeapon')
--- and the description Mote passes ('Main Weapon') both match.
---
---   @param stateField string State key or description of what changed
---   @return void
local function on_state_change(stateField)
    if type(stateField) ~= 'string' or not WEAPON_STATES[stateField:gsub(' ', '')] then
        return
    end

    if player and player.status then
        handle_equipping_gear(player.status)
    end
end

job_state_change = LifecycleManager.state_change(on_state_change)

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export global for GearSwap (Mote-Include)
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

