---============================================================================
--- FFXI GearSwap Configuration - Bard (BRD) - Modular Architecture
---============================================================================
--- Advanced Bard job configuration built on modular architecture principles.
--- This file serves as the main coordinator, delegating all specialized logic
--- to dedicated modules for maximum maintainability and scalability.
---
--- @file shared/entry/brd.lua
--- @author ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date Created: 2025-10-13
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Key Features:
---   - Modular architecture with specialized function modules
---   - Song rotation packs (song_rotation_manager, BRD_SONG_CONFIG)
---   - Instrument swapping (Gjallarhorn, Daurdabla, Marsyas)
---   - Song casting delays (BRD_TIMING_CONFIG)
---   - Pianissimo songs on party members
---   - Honor March protection (Marsyas lock)
---   - Madrigal, Minuet, Prelude support
---
--- Architecture Overview:
---   EntryKit.job >> load_job >> Specialized Modules
---
--- Module Organization:
---   ├── <Character>/brd/sets/brd_sets.lua [Equipment Sets]
---   └── functions/BRD_*.lua            [Specialized Modules]
---
--- Specialized Modules:
---   BRD_PRECAST | BRD_MIDCAST | BRD_AFTERCAST | BRD_STATUS | BRD_BUFFS
---   BRD_IDLE | BRD_ENGAGED | BRD_COMMANDS
---   BRD_MOVEMENT
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with BRD's song configs (before Mote-Include, so user_setup has them), song slots and song
-- ownership
local CharPaths = require('shared/utils/core/char_paths')
local UIConfig

local function update_song_slots()
    if _G.update_brd_song_slots then
        _G.update_brd_song_slots()
    end
end

local _
_, UIConfig = require('shared/utils/core/entry_kit').job('BRD', {
    early_configs = true,
    before_mote = function()
        _G.BRDSongConfig = require(CharPaths.module('job', 'BRD_SONG_CONFIG', 'BRD'))
        _G.BRDTimingConfig = require(CharPaths.module('job', 'BRD_TIMING_CONFIG', 'BRD'))
        -- Eager-load song rotation manager so _G.update_brd_song_slots is available
        -- when user_setup() schedules the initial UI population (avoids empty slots on reload)
        require('shared/jobs/brd/functions/logic/song_rotation_manager')
    end,
    after_setup = function()
        coroutine.schedule(update_song_slots, UIConfig.init_delay + 0.5)
        -- Which songs up are ours (end times of packet 0x063), against other
        -- bards' and Trusts' songs: shared/jobs/brd/functions/logic/song_owner.lua
        local owner_ok, SongOwner = pcall(require, 'shared/jobs/brd/functions/logic/song_owner')
        if owner_ok and SongOwner then SongOwner.start() end
    end,
    -- the song slots follow SongMode (they show the pack)
    update = update_song_slots,
    -- the instrument skill-up loop stops with the job (logic/skillup.lua)
    unload = function()
        if _G.BRDSkillUp then pcall(_G.BRDSkillUp.cancel) end
    end,
})
