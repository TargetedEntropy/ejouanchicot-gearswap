---  ═══════════════════════════════════════════════════════════════════════════
---   BRD Commands Module - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles BRD-specific commands via //gs c [command]
---
---   Job Abilities (6 commands):
---   soul_voice (sv)   - Soul Voice 1hr
---   nightingale (ni)  - Nightingale
---   troubadour (tr)   - Troubadour
---   nt                - Nightingale + Troubadour combo
---   marcato (ma)      - Marcato
---   pianissimo (pi)   - Pianissimo
---
---   Debuff Songs (4 commands, on <stnpc>; a song on recast is downgraded by
---   SongRefinement in precast when BRDSongConfig.SONG_REFINE lists it):
---   lullaby           - Horde Lullaby
---   lullaby2, foe     - Foe Lullaby II
---   elegy             - Carnage Elegy
---   requiem           - Foe Requiem VII
---
---   Pack Rotation:
---   songs, meleesong, melee, allsongs - Cast current song pack (SongMode);
---                       nothing when every song has time left (songs force)
---   songplan          - Show what `songs` would cast now, and why
---   songstop          - Stop a running song rotation
---
---   Dummy Songs (3 commands):
---   dummy, dummysongs - Cast all dummy songs
---   dummy1            - Cast dummy song 1 (BRDSongConfig.DUMMY_SONGS.standard)
---   dummy2            - Cast dummy song 2
---
---   Element/Type Songs (3 commands):
---   threnody          - Cast threnody (current ThrenodyElement state)
---   carol             - Cast carol (current CarolElement state)
---   etude             - Cast etude (current EtudeType state)
---
---   Individual Song Slots (5 commands):
---   song1             - Cast song from slot 1 of current pack
---   song2             - Cast song from slot 2 of current pack
---   song3             - Cast song from slot 3 of current pack
---   song4             - Cast song from slot 4 of current pack
---   song5             - Cast song from slot 5 of current pack
---
---   Other: forceidle (re-equip idle ring1), debugmidcast, cyclestate,
---   dual-box (altjobupdate, requestjob), UI / watchdog / common commands.
---
---   @file    shared/jobs/brd/functions/BRD_COMMANDS.lua
---   @author  ejouanchicot
---   @version 3.0 - Complete migration from old system
---   @date    Created: 2025-10-13
---  ═══════════════════════════════════════════════════════════════════════════

local MessageFormatter = nil
local SongRotationManager = nil
local BRDSongConfig = nil
local BRDTimingConfig = nil

local function ensure_commands_loaded()
    if not MessageFormatter then
        MessageFormatter = require('shared/utils/messages/message_formatter')
        SongRotationManager = require('shared/jobs/brd/functions/logic/song_rotation_manager')
        BRDSongConfig = _G.BRDSongConfig or {}  -- Loaded from character main file
        BRDTimingConfig = _G.BRDTimingConfig or {}  -- Loaded from character main file
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATIC LOOKUP TABLES (module-level constants - no recompute per call)
---  ═══════════════════════════════════════════════════════════════════════════

local THRENODIES = {Fire='Fire Threnody II', Ice='Ice Threnody II', Wind='Wind Threnody II',
    Earth='Earth Threnody II', Lightning='Ltng. Threnody II', Water='Water Threnody II',
    Light='Light Threnody II', Dark='Dark Threnody II'}

local CAROLS = {Fire='Fire Carol II', Ice='Ice Carol II', Wind='Wind Carol II',
    Earth='Earth Carol II', Lightning='Lightning Carol II', Water='Water Carol II',
    Light='Light Carol II', Dark='Dark Carol II'}

---  ═══════════════════════════════════════════════════════════════════════════
---   HELPER FUNCTIONS
---  ═══════════════════════════════════════════════════════════════════════════

--- Cast a song to the appropriate target using FFXI priority rules:
---   1. Self target  -> <me>
---   2. Other PC     -> "<player_name>"
---   3. Mob/no target -> <stpc> (subtarget or self)
--- @param song_name string Song name to cast
local function cast_song_to_target(song_name)
    if player and player.target then
        local target = player.target
        if target.id == player.id then
            send_command('input /ma "' .. song_name .. '" <me>')
            return
        end
        if target.spawn_type == 13 then
            send_command('input /ma "' .. song_name .. '" "' .. target.name .. '"')
            return
        end
    end
    send_command('input /ma "' .. song_name .. '" <stpc>')
end

---   Cast a song by name. Marcato and Pianissimo are added by BRD_PRECAST.lua,
---   after the song's recast check (do NOT add them here: sent from a command
---   they would be spent even when the song is on recast).
---   @param song_name string Song name to cast
local function cast_song(song_name)
    if not song_name then return end
    cast_song_to_target(song_name)
end

---   Use a job ability by name
---   @param ability_name string Ability name
local function use_ability(ability_name)
    if not ability_name then return end
    send_command('input /ja "' .. ability_name .. '" <me>')
end

---   Get threnody name for current element
---   @return string|nil Threnody II name for state.ThrenodyElement
local function get_current_threnody()
    return state and state.ThrenodyElement and THRENODIES[state.ThrenodyElement.current] or nil
end

---   Get carol name for current element
---   @return string|nil Carol II name for state.CarolElement
local function get_current_carol()
    return state and state.CarolElement and CAROLS[state.CarolElement.current] or nil
end

---   Get etude name for current type
---   @return string|nil Etude name for state.EtudeType (BRDSongConfig.ETUDES)
local function get_current_etude()
    if not (state and state.EtudeType and BRDSongConfig and BRDSongConfig.ETUDES) then
        return nil
    end
    return BRDSongConfig.ETUDES[state.EtudeType.current]
end

--- The spell of each debuff song command: brd/combat/BRD_SONG_CONFIG.lua DEBUFF_SONGS
local function debuff_songs()
    return require('shared/utils/core/job_config').get('BRD', 'DEBUFF_SONGS', {lullaby = 'Horde Lullaby',
        lullaby2 = 'Foe Lullaby II', elegy = 'Carnage Elegy', requiem = 'Foe Requiem VII'})
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLERS
---  ═══════════════════════════════════════════════════════════════════════════

--- The abilities a word uses, and its message: {ability, MessageFormatter function, its argument}.
--- (scripts/atelier/job_commands_test.lua checks that each named function exists)
local ABILITIES = {
    soul_voice = {'Soul Voice', 'show_ability_command', 'Soul Voice (1hr)'},
    nightingale = {'Nightingale', 'show_ability_command', 'Nightingale'},
    troubadour = {'Troubadour', 'show_ability_command', 'Troubadour'},
    marcato = {'Marcato', 'show_marcato_used'},
    pianissimo = {'Pianissimo', 'show_pianissimo_used'},
}
ABILITIES.sv, ABILITIES.ni, ABILITIES.tr = ABILITIES.soul_voice, ABILITIES.nightingale, ABILITIES.troubadour
ABILITIES.ma, ABILITIES.pi = ABILITIES.marcato, ABILITIES.pianissimo

local function ability(_, command)
    local name, show, arg = unpack(ABILITIES[command])
    use_ability(name)
    MessageFormatter[show](arg)
end

--- The debuff songs: {its key in DEBUFF_SONGS, MessageFormatter function}, on <stnpc>.
local DEBUFFS = {
    lullaby = {'lullaby', 'show_lullaby_cast'},
    lullaby2 = {'lullaby2', 'show_lullaby_cast'},
    elegy = {'elegy', 'show_elegy_cast'},
    requiem = {'requiem', 'show_requiem_cast'},
}
DEBUFFS.foe = DEBUFFS.lullaby2

local function debuff(_, command)
    local key, show = unpack(DEBUFFS[command])
    local song = debuff_songs()[key]
    send_command('input /ma "' .. song .. '" <stnpc>')
    MessageFormatter[show](song)
end

--- Song casting (pack rotations)
local function cast_pack(cmdParams)
    -- Cast current song pack using 3-phase rotation
    -- 'full': every dummy, whatever songs are up (another bard around)
    -- 'force': sing even when every song has time left (song_opening.lua)
    SongRotationManager.cast_songs_with_phases(false, '<me>', cmdParams[2] == 'full', cmdParams[2] == 'force')
end

local function cast_dummies()
    -- Cast dummy songs (4 or 5 depending on Clarion Call)
    SongRotationManager.cast_dummy_songs()
end

--- song1..song5: the song in that slot of the pack. No Clarion Call check: 5 songs can be refreshed even after
--- Clarion Call wears off.
local function song_slot(_, command)
    local slot = tonumber(command:match('^song(%d)$'))
    local songs = SongRotationManager.get_songs_with_replacement()
    if songs and songs[slot] then
        cast_song(songs[slot])
    else
        MessageFormatter.show_no_song_in_slot(slot)
    end
end

local words = {
    -- Warp ring fix
    forceidle = function(_, command)
        -- Re-equip the idle left_ring in ring1 after a warp interruption.
        -- No code in the project sends this command any more (manual use only).

        -- Step 1: Re-enable ring1 using SAME method as disable (via gs command)
        send_command('gs enable ring1')

        -- Step 2: Single /equip attempt 1 second later
        coroutine.schedule(function()
            -- Get the target ring from idle set
            -- GearSwap accepts left_ring, ring1 and lring for the same slot
            local function left_ring_of(set)
                return type(set) == 'table' and (set.left_ring or set.ring1 or set.lring) or nil
            end
            local ring_data = nil
            if sets and sets.idle then
                -- Check IdleMode
                if state and state.IdleMode and state.IdleMode.current then
                    ring_data = left_ring_of(sets.idle[state.IdleMode.current])
                end

                -- Fallback to base idle set
                ring_data = ring_data or left_ring_of(sets.idle)
            end

            -- Extract ring name (handle both string and table format)
            local ring_name = nil
            if ring_data then
                if type(ring_data) == 'table' and ring_data.name then
                    ring_name = ring_data.name
                elseif type(ring_data) == 'string' then
                    ring_name = ring_data
                end
            end

            -- Force equip using Windower /equip command (bypass GearSwap)
            -- This is more reliable than GearSwap equip() when slot is locked
            if ring_name then
                send_command('input /equip ring1 "' .. ring_name .. '"')
            end
        end, 1.0)

    end,
    -- Instrument skill-up loop: //gs c skillup horn | harp | off | status
    -- (logic/skillup.lua)
    skillup = function(cmdParams)
        require('shared/jobs/brd/functions/logic/skillup').handle(cmdParams[2])
    end,
    nt = function()
        -- Nightingale + Troubadour combo
        use_ability('Nightingale')
        local delays = BRDTimingConfig.ABILITY_DELAYS or {}
        local ability_delay = delays.nt_combo_delay or 1.5  -- safe default if config missing
        coroutine.schedule(
            function()
                use_ability('Troubadour')
            end,
            ability_delay
        )
        -- Message handled by ability_message_handler (shows individual JA descriptions)
    end,
    songs = cast_pack, meleesong = cast_pack, melee = cast_pack, allsongs = cast_pack,
    songplan = function()
        -- What //gs c songs would do now, and why (song_slots.lua)
        local SongSlots = require('shared/jobs/brd/functions/logic/song_slots')
        local songs = SongRotationManager.get_songs_with_replacement()
        local total, dummies, base = SongSlots.plan(#songs)
        local i = SongSlots.inputs()
        require('shared/utils/messages/info_block').show({
            tag = 'BRD', title = 'Song plan',
            fields = {
                {'Clarion Call', i.clarion},
                {'Main instrument', ('%s (+%d)'):format(tostring(i.main), i.main_extra)},
                {'Dummy instrument', ('%s (+%d)'):format(tostring(i.dummy), i.dummy_extra)},
                {'Songs up', ('%d mine, %d in all'):format(i.up, i.up_all)},
                {'Plan', ('%d songs, %d dummies (main opens %d)'):format(total, dummies, base)},
            },
        })
    end,
    songstop = function()
        -- Drop a running rotation (song_queue.lua)
        local stopped = require('shared/jobs/brd/functions/logic/song_queue').stop()
        stopped = require('shared/jobs/brd/functions/logic/song_opening').stop() or stopped
        require('shared/utils/messages/message_formatter').show_info(
            stopped and 'Songs: rotation stopped.' or 'Songs: no rotation running.')
    end,
    dummy = cast_dummies, dummysongs = cast_dummies,
    dummy1 = function()
        local dummy_songs = SongRotationManager.get_dummy_songs()
        if dummy_songs and dummy_songs[1] then
            cast_song(dummy_songs[1])
            -- DISABLED: Message already shown by midcast_router.lua (show_daurdabla_dummy)
            -- MessageFormatter.show_dummy_cast(dummy_songs[1])
        end
    end,
    dummy2 = function()
        local dummy_songs = SongRotationManager.get_dummy_songs()
        if dummy_songs and dummy_songs[2] then
            cast_song(dummy_songs[2])
            -- DISABLED: Message already shown by midcast_router.lua (show_daurdabla_dummy)
            -- MessageFormatter.show_dummy_cast(dummy_songs[2])
        end
    end,
    threnody = function()
        local threnody = get_current_threnody()
        if not threnody then
            MessageFormatter.show_no_element_selected()
            return
        end

        local element = state.ThrenodyElement.current
        send_command('input /ma "' .. threnody .. '" <stnpc>')
        MessageFormatter.show_threnody_cast(element)
    end,
    carol = function()
        local carol = get_current_carol()
        if not carol then
            MessageFormatter.show_no_carol_element()
            return
        end

        local element = state.CarolElement.current
        cast_song(carol)
        MessageFormatter.show_carol_cast(element)
    end,
    etude = function()
        local etude = get_current_etude()
        if not etude then
            MessageFormatter.show_no_etude_type()
            return
        end

        local stat = state.EtudeType.current
        cast_song(etude)
        MessageFormatter.show_etude_cast(stat)
    end,
}
for slot = 1, 5 do words['song' .. slot] = song_slot end
for word in pairs(ABILITIES) do words[word] = ability end
for word in pairs(DEBUFFS) do words[word] = debuff end

job_self_command = JobCommands.router('BRD', {load = ensure_commands_loaded, words = words})

--- BRD adds nothing of its own: the shared handler is the whole
--- behaviour. Pass a function to state_change() to extend it.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export to global scope
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

