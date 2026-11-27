---============================================================================
--- Common Commands - Commands shared by every job
---============================================================================
--- Router for the `//gs c <command>` words every job answers (warp aliases,
--- naked, mount, reload, checksets, wardrobe, refill, craft, lockstyle, alt
--- commands, debug toggles, help...). Each job's [JOB]_COMMANDS.lua forwards
--- here; handle_command() returns false when the word is not a common command
--- so the job can try its own.
---
--- Diagnostic handlers live in DEBUG_COMMANDS.lua, craft/fish handlers in
--- craft/craft_commands.lua and the gear ones in GEAR_COMMANDS.lua; all are
--- re-exposed as CommonCommands.handle_*.
---
--- @file    shared/utils/core/COMMON_COMMANDS.lua
--- @author  ejouanchicot
--- @version 3.4 - one WORDS table instead of an if-chain and a word list kept in step with it
--- @date    Created: 2025-11-03
---============================================================================

local CommonCommands = {}

local MessageCommands  = require('shared/utils/messages/formatters/ui/message_commands')
local MessageFormatter = require('shared/utils/messages/message_formatter')

-- Warp shortcuts (single source of truth in warp_command_registry).
local WarpRegistry = require('shared/utils/warp/warp_command_registry')

-- Alt commands are consulted for every command nothing else answered, so
-- resolve the module once instead of pcall(require) per call. `false` means
-- "tried and failed".
local AltCommandsModule = nil
local function alt_commands()
    if AltCommandsModule == nil then
        local ok, mod = pcall(require, 'shared/utils/dualbox/alt_commands')
        AltCommandsModule = (ok and mod) or false
    end
    return AltCommandsModule or nil
end

-- RELOAD COMMAND

--- Reload the job file through JobChangeManager.force_reload().
--- @param job_name string|nil Fallback main job when `player` is unavailable
--- @return boolean True if the reload was requested
function CommonCommands.handle_reload(job_name)
    local jcm_success, JobChangeManager = pcall(require, 'shared/utils/core/job_change_manager')
    if jcm_success and JobChangeManager then
        local main_job = player and player.main_job or job_name
        local sub_job = player and player.sub_job or "SAM"
        JobChangeManager.force_reload(main_job, sub_job)
        return true
    else
        local MessageFormatter = require('shared/utils/messages/message_formatter')
        MessageFormatter.show_error("Failed to load job change manager")
        return false
    end
end

-- JUMP COMMAND (SUB DRG)

--- Use the best available Jump (DRG main or sub).
--- @return boolean True if the jump manager loaded
function CommonCommands.handle_jump()
    local drg_success, DRGJumpManager = pcall(require, 'shared/utils/drg/DRG_JUMP_MANAGER')
    if drg_success and DRGJumpManager then
        DRGJumpManager.execute_jump()
        return true
    else
        local MessageFormatter = require('shared/utils/messages/message_formatter')
        MessageFormatter.show_error("Failed to load DRG jump manager")
        return false
    end
end

-- WALTZ COMMANDS (DNC MAIN/SUB)

--- Shared body of the curing / divine waltz commands.
--- @param waltz_type string 'curing' or 'divine'
--- @param error_msg string Message shown when neither main nor sub is DNC
--- @return boolean True if a waltz was attempted
local function handle_waltz_generic(waltz_type, error_msg)
    if player.main_job ~= 'DNC' and player.sub_job ~= 'DNC' then
        local MessageFormatter = require('shared/utils/messages/message_formatter')
        MessageFormatter.show_error(error_msg)
        return false
    end

    -- Cancel Saber Dance if active
    if buffactive['Saber Dance'] then
        send_command('cancel Saber Dance')
    end

    local waltz_success, WaltzManager = pcall(require, 'shared/utils/dnc/waltz_manager')
    if waltz_success and WaltzManager then
        if waltz_type == 'curing' then
            WaltzManager.cast_curing_waltz('<stpc>')
        elseif waltz_type == 'divine' then
            WaltzManager.cast_divine_waltz()
        end
        return true
    else
        local MessageFormatter = require('shared/utils/messages/message_formatter')
        MessageFormatter.show_error("Failed to load waltz manager")
        return false
    end
end

--- Curing Waltz on <stpc>, tier chosen by WaltzManager.
--- @return boolean True if a waltz was attempted
function CommonCommands.handle_waltz()
    return handle_waltz_generic('curing', "Waltz requires DNC main or subjob")
end

--- Divine Waltz (AoE).
--- @return boolean True if a waltz was attempted
function CommonCommands.handle_aoewaltz()
    return handle_waltz_generic('divine', "Divine Waltz requires DNC main or subjob")
end

-- MOUNT COMMAND (ALL JOBS)

--- Handle mount toggle command (dismount if riding, else random owned mount)
--- @return boolean Success status
function CommonCommands.handle_mount()
    local mount_success, MountManager = pcall(require, 'shared/utils/mount/mount_manager')
    if not mount_success or not MountManager then
        local MessageFormatter = require('shared/utils/messages/message_formatter')
        MessageFormatter.show_error("Failed to load mount manager")
        return false
    end

    return MountManager.toggle()
end

-- GEAR COMMANDS (checksets, wardrobe, refill, automedicine, testcolors, naked, lockstyle, dressup):
-- in GEAR_COMMANDS.lua since 2026-11-14, re-exposed here for the router below.
local GearCommands = require('shared/utils/core/GEAR_COMMANDS')
CommonCommands.handle_automedicine = GearCommands.handle_automedicine
CommonCommands.handle_checksets = GearCommands.handle_checksets
CommonCommands.handle_dressup = GearCommands.handle_dressup
CommonCommands.handle_lockstyle = GearCommands.handle_lockstyle
CommonCommands.handle_naked = GearCommands.handle_naked
CommonCommands.handle_refill = GearCommands.handle_refill
CommonCommands.handle_testcolors = GearCommands.handle_testcolors
CommonCommands.handle_wardrobeaudit = GearCommands.handle_wardrobeaudit
CommonCommands.handle_wardrobeorganize = GearCommands.handle_wardrobeorganize

-- ALT COMMANDS (dual-box: drive the alt from the main)

--- Run a command defined in the alt's per-job config, or list them.
--- `//gs c altcmds` lists what the alt's current job offers.
--- `//gs c alt <name>` is the explicit form; bare `//gs c <name>` also works
--- for any name no local command answers (AltCommands.install_fallback).
--- @param cmd string Command name
--- @param args table Arguments after the command
--- @return boolean Success status
function CommonCommands.handle_alt_command(cmd, args)
    local AltCommands = alt_commands()
    if not AltCommands then
        MessageFormatter.show_error("Failed to load alt commands module.")
        return false
    end
    return AltCommands.handle(cmd, args, CommonCommands.runs_locally)
end

-- CRAFT / FISH COMMANDS - extracted to CRAFT_COMMANDS.lua, re-exposed here.
local CraftCommands = require('shared/utils/craft/craft_commands')
CommonCommands.handle_craft   = CraftCommands.handle_craft
CommonCommands.handle_fish    = CraftCommands.handle_fish
CommonCommands.handle_uncraft = CraftCommands.handle_uncraft

-- DIAGNOSTIC COMMANDS

-- Diagnostic / debug-toggle handlers live in DEBUG_COMMANDS.lua; the router
-- reaches them through DebugCommands.WORDS / DebugCommands.run.
local DebugCommands = require('shared/utils/core/DEBUG_COMMANDS')

-- WARP COMMANDS (Universal Warp/Teleport System)

--- Run a warp command through WarpCommands. When the module fails to load,
--- print the error and try its dependencies one by one.
--- @param cmdParams table Full command, cmdParams[1] being the command word
--- @return boolean Result of WarpCommands.handle_command, false on load failure
function CommonCommands.handle_warp_commands(cmdParams)
    local warp_success, WarpCommands = pcall(require, 'shared/utils/warp/warp_commands')
    if warp_success and WarpCommands then
        return WarpCommands.handle_command(cmdParams)
    else
        MessageCommands.show_warp_error_header()
        MessageCommands.show_warp_error(WarpCommands)
        MessageCommands.show_warp_error_footer()

        MessageCommands.show_warp_testing_modules()

        local test1, res1 = pcall(require, 'shared/utils/warp/warp_item_database')
        MessageCommands.show_warp_module_test('WarpItemDB', test1, res1)

        local test2, res2 = pcall(require, 'shared/utils/messages/formatters/system/message_warp')
        MessageCommands.show_warp_module_test('MessageWarp', test2, res2)

        local test3, res3 = pcall(require, 'shared/utils/warp/warp_equipment')
        MessageCommands.show_warp_module_test('WarpEquipment', test3, res3)

        MessageCommands.show_warp_error_footer()

        return false
    end
end

-- MAIN COMMAND ROUTER

local function alt_buff_reporter()
    local ok, AltBuffReporter = pcall(require, 'shared/utils/dualbox/alt_buff_reporter')
    return ok and AltBuffReporter or nil
end

--- A module's function, loaded when the word is first used: by(module, fn) runs require(module)[fn](args).
local function by(module, fn)
    return function(args) return require(module)[fn](args) end
end

--- The words handle_command() answers, each one with its handler fn(args, cmdParams, job_name), args being the
--- words after it. Besides these: the diagnostics (DEBUG_COMMANDS.lua WORDS), the warp aliases
--- (warp_command_registry.lua, and their "<alias>all" form) and ja<n>. No word is in two of these lists.
local WORDS = {
    -- Sortie: this character's stance + the GEO alt's Silmaril profile
    sortie = by('shared/utils/sortie/sortie_commands', 'handle'),
    -- A COR alt's roll result / bust, shown here in the same format
    rollshow = by('shared/utils/dualbox/roll_share', 'receive'),
    -- Sneak / Invisible, debuff removal on every character of the box group
    stealth = by('shared/utils/stealth/stealth', 'handle'),
    cleanse = by('shared/utils/debuff/cleanse', 'handle'),
    -- Combat Mode: weapon lock, shown or hidden per job
    combatmode = by('shared/utils/core/combat_mode_commands', 'handle'),
    -- Every key conflict the loaded job can run into, all subjobs and partners
    keyconflicts = function() return require('shared/utils/keybinds/keybind_manager').show_possible_conflicts() end,
    -- Treasure Mode on this job: status, show / hide, key, clear the tags
    th = by('shared/utils/equipment/treasure_commands', 'handle'),
    -- Dual Wield tier by magic haste: estimate, or force a tier
    dw = by('shared/utils/equipment/dual_wield', 'command'),
    -- Weaponskill set by party support: tier and party, or force a tier
    support = by('shared/utils/party/support_tier', 'command'),
    -- Fights and kills of the session; timers a Random Deal / Wild Card gave back
    fights = by('shared/utils/combat/fight_tracker', 'command'),
    dealwatch = by('shared/utils/combat/random_deal_watch', 'command'),
    -- Hachirin-no-Obi / Orpheus's Sash: state and today's bonuses
    belt = function() return require('shared/utils/equipment/elemental_belt').show_status() end,
    -- Temporary keybinds for a repetitive task
    tb = by('shared/utils/keybinds/temp_binds', 'handle'),
    -- Record what the game really returns to <Character>/logs/trace/trace.log
    trace = by('shared/utils/debug/trace_log', 'handle'),
    -- Data for the Atelier page (data/atelier.html)
    atelier = by('shared/utils/atelier/atelier_export', 'handle'),

    naked = function() return CommonCommands.handle_naked() end,
    equip = function(args)
        if args[1] and args[1]:lower() == 'naked' then return CommonCommands.handle_naked() end
        MessageFormatter.show_warning('Usage: //gs c equip naked')
        return true
    end,
    mount = function() return CommonCommands.handle_mount() end,
    reload = function(_, _, job_name) return CommonCommands.handle_reload(job_name) end,
    checksets = function(_, _, job_name) return CommonCommands.handle_checksets(job_name) end,
    wardrobeaudit = function() return CommonCommands.handle_wardrobeaudit() end,
    worganize = function(args) return CommonCommands.handle_wardrobeorganize(args[1], args[2]) end,
    -- every lockstyle set the character uses, applied in turn so its pieces are written down
    lockscan = by('shared/utils/lockstyle/lockstyle_pieces', 'scan'),
    -- the tidy-up plan sent by the Atelier page (shared/utils/wardrobe/bag_mover.lua)
    bags = by('shared/utils/wardrobe/bag_mover', 'handle'),
    -- PorterPacker for the job loaded, then the wardrobes and the refill (shared/utils/wardrobe/porter_run.lua)
    porter = function() return require('shared/utils/wardrobe/porter_run').start() end,
    refill = function() return CommonCommands.handle_refill() end,
    automedicine = function(args) return CommonCommands.handle_automedicine(args[1]) end,
    craft = function(args) return CommonCommands.handle_craft(args[1]) end,
    fish = function(args) return CommonCommands.handle_fish(args[1]) end,
    uncraft = function() return CommonCommands.handle_uncraft() end,
    lockstyle = function() return CommonCommands.handle_lockstyle() end,
    dressup = function() return CommonCommands.handle_dressup() end,
    perf = function(args) return DebugCommands.handle_perf(args[1]) end,
    testcolors = function() return CommonCommands.handle_testcolors() end,
    jump = function() return CommonCommands.handle_jump() end,
    waltz = function() return CommonCommands.handle_waltz() end,
    aoewaltz = function() return CommonCommands.handle_aoewaltz() end,
    -- main job's buffs then the subjob's (BUFF_CONFIG.lua)
    buff = function() return require('shared/utils/buffs/buff_command').apply() end,
    gearscan = function() return require('shared/utils/equipment/gear_scan').run() end,
    hporder = function() require('shared/utils/equipment/hp_priority').toggle_order_display() return true end,
    commands = function() MessageCommands.show_commands_list() return true end,
    help = function() MessageCommands.show_help() return true end,

    -- Sent by the ALT when a tracked buff goes up or down.
    altbuff = function(args)
        local AltBuffReporter = alt_buff_reporter()
        if AltBuffReporter then AltBuffReporter.receive(args) end
        return true
    end,
    -- Sent BY the main TO the alt: resend every tracked buff.
    altbuffsync = function()
        local AltBuffReporter = alt_buff_reporter()
        if AltBuffReporter then AltBuffReporter.report_all() end
        return true
    end,
    -- Run on the main: ask the alt to resend its buff state.
    altsync = function()
        local AltBuffReporter = alt_buff_reporter()
        if AltBuffReporter and AltBuffReporter.request_sync() then
            MessageFormatter.show_debug('ALTBUFF', 'Asked the alt to resync its buffs.')
        else
            MessageFormatter.show_error('Alt sync needs dual-boxing enabled as main.')
        end
        return true
    end,
    -- Diagnostic: what the main currently believes about the alt's buffs.
    altbuffs = function()
        local AltBuffReporter = alt_buff_reporter()
        if AltBuffReporter then AltBuffReporter.show_state() end
        return true
    end,
    -- Trace buff reporting on whichever character you run it on.
    altdebug = function()
        local AltBuffReporter = alt_buff_reporter()
        if AltBuffReporter then
            local on, path = AltBuffReporter.toggle_debug()
            MessageFormatter.show_debug('ALTBUFF', 'Tracing ' .. (on and 'ON' or 'OFF'))
            if on then
                MessageFormatter.show_debug('ALTBUFF', 'Log: ' .. path)
            end
        end
        return true
    end,
}
-- Box group: orders to the alts (alts), role switch (main / setalt), real state reported by the automation addon
for _, word in ipairs({'alts', 'main', 'setalt', 'altreport', 'altmirror', 'altlead'}) do
    WORDS[word] = function(args) return require('shared/utils/dualbox/alt_group').route(word, args) end
end
-- The alt's per-job commands, listed or run
for _, word in ipairs({'alt', 'altcmds', 'altlist'}) do
    WORDS[word] = function(args) return CommonCommands.handle_alt_command(word, args) end
end
-- The installed version, and the update through the Atelier page
for _, word in ipairs({'version', 'upgrade'}) do
    WORDS[word] = function() return require('shared/utils/core/release_info').handle(word) end
end
for _, word in ipairs({'lightarts', 'darkarts', 'aoe'}) do
    WORDS[word] = function(args) return require('shared/utils/scholar/scholar_actions').handle_command(word, args[1]) end
end
for alias, word in pairs({kc = 'keyconflicts', wa = 'wardrobeaudit', wo = 'worganize', po = 'porter', rf = 'refill',
    am = 'automedicine', fishing = 'fish', ls = 'lockstyle', colors = 'testcolors', buffs = 'buff', buffself = 'buff',
    selfbuff = 'buff', smartbuff = 'buff', cmds = 'commands', ['?'] = 'help'}) do
    WORDS[alias] = WORDS[word]
end

--- A warp alias, or its multi-boxing form "<alias>all" (warpall, tphall, sdall...).
local function is_warp(cmd)
    return WarpRegistry.SET[cmd] == true or (cmd:find('all$') ~= nil and WarpRegistry.SET[(cmd:gsub('all$', ''))] == true)
end

--- Route a common command. Accepts either the command word followed by its
--- arguments, or a cmdParams table ({word, arg1, ...}) as first argument.
--- @param command string|table Command word, or the full cmdParams table
--- @param job_name string|nil Job code (used by reload and checksets)
--- @param ... string Arguments after the command word (string form only)
--- @return boolean True if a common command handled it
function CommonCommands.handle_command(command, job_name, ...)
    if not command then
        return false
    end

    -- Support both string command and table cmdParams (for warp system)
    local cmd, cmdParams
    if type(command) == "table" then
        cmdParams = command
        cmd = cmdParams[1] and cmdParams[1]:lower() or ""
    else
        cmd = command:lower()
        cmdParams = {command, ...}
    end
    local args = {unpack(cmdParams, 2)}

    local handler = WORDS[cmd]
    if handler then
        return handler(args, cmdParams, job_name)
    end

    -- Diagnostics and in-game test tools (DEBUG_COMMANDS.lua WORDS)
    local debug = DebugCommands.run(cmd, args)
    if debug ~= nil then return debug end

    -- Every alias in warp_command_registry.COMMANDS
    if is_warp(cmd) then
        return CommonCommands.handle_warp_commands(cmdParams)
    end

    -- ja1, ja2... (or ja 1): the subjob's ability at that place (SUBJOB_CONFIG.lua abilities)
    if cmd:match('^ja%d*$') then
        local SubAbilities = require('shared/utils/commands/sub_abilities')
        local index = SubAbilities.index_of(cmd, args[1])
        if index then return SubAbilities.use(index) end
        return SubAbilities.usage()
    end

    return false
end

-- HELPER FUNCTIONS

--- Check if a word is answered by handle_command().
--- @param command string|nil Command word
--- @return boolean True for a common command, a diagnostic, a warp alias or ja<n>
function CommonCommands.is_common_command(command)
    if not command then
        return false
    end
    local cmd = command:lower()
    return WORDS[cmd] ~= nil or DebugCommands.WORDS[cmd] ~= nil or cmd:match('^ja%d*$') ~= nil or is_warp(cmd)
end

--- Every word of WORDS (the tests compare it with the help pages)
function CommonCommands.words()
    local out = {}
    for word in pairs(WORDS) do out[#out + 1] = word end
    table.sort(out)
    return out
end

-- ALT COMMANDS AS A LAST RESORT

--- Does this name run on this character rather than reach the alt?
--- True for common commands, warp aliases and Mote's own commands.
--- @param name string Command word
--- @return boolean True when a bare `//gs c <name>` never reaches the alt
function CommonCommands.runs_locally(name)
    if CommonCommands.is_common_command(name) then
        return true
    end
    local maps = rawget(_G, 'selfCommandMaps')
    return type(maps) == 'table' and rawget(maps, name) ~= nil
end

-- Alt keys answer only what nothing on this side does: they are Mote's last
-- lookup, never a common command (AltCommands.install_fallback). Installed
-- once per job file load, when the first command loads this module.
local AltCommandsAtLoad = alt_commands()
if AltCommandsAtLoad then
    AltCommandsAtLoad.install_fallback(rawget(_G, 'selfCommandMaps'), CommonCommands.runs_locally)
end

return CommonCommands