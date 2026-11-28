---============================================================================
--- Entry Kit - every job's entry
---============================================================================
--- Each entry (shared/entry/<job>.lua) is one EntryKit.job call: the six
--- globals GearSwap and Mote call (get_sets, init_gear_sets, user_setup,
--- job_sub_job_change, job_update, file_unload) are defined here, and the
--- entry hands in only the steps its job adds (a lock to release first, an
--- addon to unload, a pet loop to stop).
---
--- @file    shared/utils/core/entry_kit.lua
--- @author  ejouanchicot
--- @version 1.0
--- @date    Created: 2026-10-15
---============================================================================

-- First: char_paths installs the require cache (ModuleCache), so that every module required from here on is
-- loaded once per sandbox. A one-line entry requires this file before anything else.
require('shared/utils/core/char_paths')
local try_require = require('shared/utils/core/try_require')

local EntryKit = {}

-- after user_setup(), get_sets() has loaded the job's files by then (load_job)
local JOB_FILES_WAIT = 0.2

local function formatter()
    return try_require('shared/utils/messages/message_formatter')
end

--- What an entry reads when its file is loaded, before get_sets: the lockstyle
--- delays (the character's LOCKSTYLE_CONFIG, an 8 s first lockstyle without
--- one), the region colours (REGION_CONFIG, read by message_colors as
--- _G.RegionConfig at each use: set before the first coloured message) and the
--- HUD settings (ConfigLoader.load_ui_config, which also sets _G.UIConfig:
--- UI_MANAGER reads it when it loads, so it comes before UI_MANAGER).
--- @return table LockstyleConfig, table UIConfig
local function load_configs(job, CharPaths)
    local LockstyleConfig = try_require(CharPaths.module('common', 'LOCKSTYLE_CONFIG')) or {initial_load_delay = 8.0}
    local RegionConfig = try_require(CharPaths.module('common', 'REGION_CONFIG'))
    if RegionConfig then
        _G.RegionConfig = RegionConfig
    end
    local UIConfig = require('shared/utils/config/config_loader').load_ui_config(CharPaths.name(), job)
    return LockstyleConfig, UIConfig
end

--- get_sets' middle, right after include('Mote-Include.lua'): the shared systems,
--- the spell / ability / weaponskill data, the three message hooks.
local function after_mote(Profiler)
    include('../shared/utils/core/INIT_SYSTEMS.lua')
    Profiler.mark('After INIT_SYSTEMS')
    require('shared/utils/data/data_loader')
    Profiler.mark('After data_loader')
    include('../shared/hooks/init_spell_messages.lua')
    Profiler.mark('After spell messages')
    include('../shared/hooks/init_ability_messages.lua')
    Profiler.mark('After ability messages')
    include('../shared/hooks/init_ws_messages.lua')
    Profiler.mark('After WS messages')
end

--- The job's hook files (shared/jobs/<job>/functions/<JOB>_<HOOK>.lua), in load
--- order. Every job has the eight in HOOKS; JOB_FILES says what a job has besides
--- (or without):
---   buff_messages = false  no buff gain / loss messages (message_buffs.lua)
---   pet_midcast            <JOB>_PET_MIDCAST.lua, after MIDCAST
---   movement               <JOB>_MOVEMENT.lua, after COMMANDS
---   own                    <job>_functions.lua: what the job defines besides its hooks
---                          (BLM's checkArts / CastStorm..., THF's Treasure Hunter start)
local HOOKS = {'PRECAST', 'MIDCAST', 'AFTERCAST', 'IDLE', 'ENGAGED', 'STATUS', 'BUFFS', 'COMMANDS'}
local JOB_FILES = {
    BLM = {own = true},
    BRD = {buff_messages = false, movement = true},
    BST = {pet_midcast = true},
    COR = {movement = true},
    DRG = {pet_midcast = true},
    PUP = {pet_midcast = true},
    RDM = {buff_messages = false},
    SAM = {buff_messages = false},
    SMN = {pet_midcast = true},
    THF = {own = true},
    WAR = {movement = true},
    WHM = {buff_messages = false},
}

--- The files load_job includes for a job, in order (the tests read it).
--- @param job string The job's code
--- @return table paths, from data/ ('../shared/...')
function EntryKit.job_files(job)
    local jl, spec = job:lower(), JOB_FILES[job] or {}
    local dir = '../shared/jobs/' .. jl .. '/functions/'
    local files = {}
    if spec.buff_messages ~= false then
        files[#files + 1] = '../shared/utils/messages/formatters/magic/message_buffs.lua'
    end
    for _, hook in ipairs(HOOKS) do
        files[#files + 1] = dir .. job .. '_' .. hook .. '.lua'
        if hook == 'MIDCAST' and spec.pet_midcast then files[#files + 1] = dir .. job .. '_PET_MIDCAST.lua' end
        if hook == 'COMMANDS' and spec.movement then files[#files + 1] = dir .. job .. '_MOVEMENT.lua' end
    end
    if spec.own then files[#files + 1] = dir .. jl .. '_functions.lua' end
    return files
end

--- Everything a job defines: what the previous job scheduled is cancelled first;
--- then its lockstyle and macro book (the shared managers, shared/data/job_defaults.lua)
--- and its hook files (EntryKit.job_files), each timed under //gs c perf; then the
--- job's lockstyle cancel (defined by LockstyleManager.install) goes to JobChangeManager.
--- @param JobChangeManager table|nil EntryKit.job's
local function load_job(job, Profiler, JobChangeManager)
    if JobChangeManager then
        JobChangeManager.cancel_all()
    end
    local TIMER = require('shared/utils/debug/performance_profiler').create_timer(job)
    require('shared/utils/lockstyle/lockstyle_manager').install(job)
    require('shared/utils/macrobook/macrobook_manager').install(job)
    for _, file in ipairs(EntryKit.job_files(job)) do
        include(file)
        TIMER(file:match('([^/]+)%.lua$'))
    end
    -- auto-initialises, and handles the main <-> alt messages
    require('shared/utils/dualbox/dualbox_manager')
    TIMER('TOTAL ' .. job .. ' files', true)
    Profiler.mark('After ' .. job:lower() .. ' files')
    local cancel = rawget(_G, 'cancel_' .. job:lower() .. '_lockstyle_operations')
    if JobChangeManager and cancel then
        JobChangeManager.register_lockstyle_cancel(job, cancel)
    end
end

--- job_update's end (Mote, after every cycle/set/toggle and gs c update): refresh
--- the HUD. Step 2 of the //gs c debugupdate trace (step 1 is AutoMove's send,
--- the next ones UI_MANAGER's and the job's customize hooks).
local function update_hud(job)
    if _G.LagDebugger then _G.LagDebugger.on_job_update() end
    if _G.UPDATE_DEBUG then
        local now = os.clock()
        local delta = _G._update_sent_time and (now - _G._update_sent_time) or 0
        local MessageFormatter = formatter()
        if MessageFormatter then
            MessageFormatter.show_debug(job, string.format(
                '[UPDATE_DEBUG] 2. job_update RECEIVED | t=%.3f | delta=%.3fms', now, delta * 1000))
        end
    end
    local KeybindUI = try_require('shared/utils/ui/UI_MANAGER')
    if KeybindUI and KeybindUI.update then
        KeybindUI.update()
    end
end

--- True when this sandbox was loaded for another subjob than the game's: a
--- subjob change is under way and JobChangeManager will reload the file.
--- Compares only when both name a subjob (no subjob reads differently in
--- GearSwap and in the game, as in LoadGate.still_current).
--- @return boolean
function EntryKit.reload_pending()
    local state = rawget(_G, 'JobChangeManagerSTATE')
    local loaded_for = state and state.current_sub_job
    local now = player and player.sub_job
    return loaded_for ~= nil and now ~= nil and loaded_for ~= now
end

--- First macro book, then the lockstyle `lockstyle_delay` seconds later.
--- Waits for the job's files (load_job): user_setup() runs inside include('Mote-Include.lua'),
--- before get_sets() loads them, and the two functions came early only when
--- the keybinds loaded (KeybindManager's intro requires them). Without keys,
--- both used to be skipped without a word. Through LoadGate: a newer load or a
--- job change drops it.
---
--- On a subjob change Mote calls user_setup() again in the OLD sandbox, before
--- job_sub_job_change (Mote-Include.lua:981-989), with player.sub_job already
--- the new one: LoadGate sees nothing to drop, and the macro book went out
--- twice (now, and again from the reload 2 s later). The load-time subjob
--- JobChangeManager seeded tells the two calls apart.
--- @param lockstyle_delay number Seconds (LOCKSTYLE_CONFIG initial_load_delay)
--- @return void
function EntryKit.macro_and_lockstyle(lockstyle_delay)
    if EntryKit.reload_pending() then
        pcall(function()
            require('shared/utils/debug/trace_log').log('LOAD', 'macro book left to the reload (subjob changed)')
        end)
        return
    end
    require('shared/utils/core/load_gate').defer(JOB_FILES_WAIT, function()
        if player and select_default_macro_book then
            select_default_macro_book()
        end
        if select_default_lockstyle then
            coroutine.schedule(select_default_lockstyle, lockstyle_delay)
        end
    end, 'macro book')
end

--- A job's whole entry (shared/entry/<job>.lua): get_sets, init_gear_sets,
--- user_setup, job_sub_job_change, job_update and file_unload, defined as the
--- sandbox's globals in the order every job used to write them out. A job hands
--- in only the steps it adds, each at a fixed point:
---
---   get_sets          Profiler, before_mote(), [early configs], Mote-Include,
---                     after_mote, [configs], configs(), load_job, after_load()
---   init_gear_sets    the character's <job>_sets.lua, after_sets()
---   user_setup        <JOB>_STATES.configure(), after_states(), keybinds
---                     (keybinds_delay s later when set), HUD, after_ui(),
---                     JobChangeManager + first macro book / lockstyle,
---                     after_setup(), dual-box manager
---   job_update        update(), then the HUD (it shows what update() changed)
---   job_sub_job_change  JobChangeManager.on_job_change (it debounces and reloads)
---   file_unload       unload(next_file), then the job change cancelled and the
---                     keys unbound
---
--- The common configs are _G.LockstyleConfig, _G.UIConfig, _G.RECAST_CONFIG and
--- _G.<JOB>TPConfig (none with tp_config = false). They are set right after
--- Mote-Include, or before it with early_configs = true, for a job whose
--- user_setup reads them (BRD, BST). The keybind module is _G.<JOB>Keybinds.
--- @param job string The job's code ('WAR')
--- @param spec table|nil The job's steps (see above)
--- @return table LockstyleConfig, table UIConfig (load_configs)
function EntryKit.job(job, spec)
    spec = spec or {}
    local jl = job:lower()
    local CharPaths = require('shared/utils/core/char_paths')
    local LockstyleConfig, UIConfig = load_configs(job, CharPaths)
    -- after load_configs: UI_MANAGER reads _G.UIConfig when it loads. Both once, for every hook below.
    local JobChangeManager = try_require('shared/utils/core/job_change_manager')
    local KeybindUI = try_require('shared/utils/ui/UI_MANAGER')

    local function common_configs()
        _G.LockstyleConfig = LockstyleConfig
        _G.UIConfig = UIConfig
        _G.RECAST_CONFIG = require(CharPaths.module('common', 'RECAST_CONFIG'))
        if spec.tp_config ~= false then
            _G[job .. 'TPConfig'] = require(CharPaths.module('job', job .. '_TP_CONFIG', job))
        end
    end

    _G.get_sets = function()
        local Profiler = require('shared/utils/debug/performance_profiler')
        Profiler.start('get_sets')
        if spec.before_mote then spec.before_mote() end
        if spec.early_configs then common_configs() end
        _G.mote_include_version = 2
        include('Mote-Include.lua')
        Profiler.mark('After Mote-Include')
        -- the shared systems, the data, the spell / ability / weaponskill messages
        after_mote(Profiler)
        if not spec.early_configs then common_configs() end
        if spec.configs then spec.configs() end
        Profiler.mark('After configs')
        -- what the last job scheduled is cancelled, the job's files loaded, its lockstyle cancel registered
        load_job(job, Profiler, JobChangeManager)
        if spec.after_load then spec.after_load() end
        Profiler.finish()
    end

    -- Mote, at the end of init_include(), after user_setup()
    _G.init_gear_sets = function()
        include(CharPaths.relative('sets', jl .. '_sets.lua', job))
        if spec.after_sets then spec.after_sets() end
    end

    local function bind_keys()
        local ok, keybinds = pcall(require, CharPaths.module('job', job .. '_KEYBINDS', job))
        if ok and keybinds then
            _G[job .. 'Keybinds'] = keybinds
            keybinds.bind_all()
        else
            -- Loudly: otherwise the job loads, //gs c answers, and only the keys are dead. A failed
            -- pcall(require) does not mean the file is missing (the sandbox require raises the same way for an
            -- error in any dependency), so the real message is the one to show.
            local MessageFormatter = formatter()
            if MessageFormatter then
                MessageFormatter.show_error('[' .. job .. '] Keybinds failed to load: ' .. tostring(keybinds))
            end
        end
    end

    -- Mote, from init_include() (inside include('Mote-Include.lua'), before
    -- init_gear_sets) and again on every subjob change, before job_sub_job_change()
    _G.user_setup = function()
        require(CharPaths.module('job', job .. '_STATES', job)).configure()
        if spec.after_states then spec.after_states() end
        if spec.keybinds_delay then
            coroutine.schedule(bind_keys, spec.keybinds_delay)
        else
            bind_keys()
        end
        if KeybindUI then
            KeybindUI.smart_init(job, UIConfig.init_delay)
        else
            local MessageFormatter = formatter()
            if MessageFormatter then
                MessageFormatter.show_error('[' .. job .. '] Failed to load UI_MANAGER')
            end
        end
        if spec.after_ui then spec.after_ui(KeybindUI) end
        if JobChangeManager then
            JobChangeManager.initialize()
            EntryKit.macro_and_lockstyle(LockstyleConfig.initial_load_delay)
        end
        if spec.after_setup then spec.after_setup() end
        -- the require() starts dualbox_manager (once per gs reload): request_alt_job as MAIN,
        -- send_job_update as ALT. Covers a main job change: job_sub_job_change is subjob-only.
        pcall(require, 'shared/utils/dualbox/dualbox_manager')
    end

    -- Mote, on a subjob change: JobChangeManager debounces and reloads (the entry's job while player is not
    -- readable). The dual-box message goes from user_setup() after the reload.
    _G.job_sub_job_change = function(new_subjob)
        if JobChangeManager then
            JobChangeManager.on_job_change(player and player.main_job or job, new_subjob)
        end
    end

    -- Mote, after every cycle / set / toggle and gs c update
    _G.job_update = function()
        if spec.update then spec.update() end
        update_hud(job)
    end

    -- GearSwap, when this job file is unloaded (job change, reload). The job's own releases come first: GearSwap
    -- runs file_unload in a single pcall, so an error further down must not keep a slot locked into the next job.
    -- Then what the job change had scheduled is cancelled, and the keys are unbound (Windower binds outlive a gs
    -- reload).
    _G.file_unload = function(next_file)
        if spec.unload then spec.unload(next_file) end
        if JobChangeManager then
            JobChangeManager.cancel_all()
        end
        local keybinds = rawget(_G, job .. 'Keybinds')
        if keybinds and keybinds.unbind_all then
            keybinds.unbind_all()
        end
    end

    return LockstyleConfig, UIConfig
end

return EntryKit
