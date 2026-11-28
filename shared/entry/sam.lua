---============================================================================
--- FFXI GearSwap Configuration - Samurai (SAM) - Modular Architecture
---============================================================================
--- Main coordinator for Samurai job configuration. Loads Mote-Include, the
--- shared systems and the SAM modules (EntryKit.load_job_files).
---
--- @file shared/entry/sam.lua
--- @author ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date Created: 2025-10-21
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with nothing SAM adds
require('shared/utils/core/entry_kit').job('SAM')
