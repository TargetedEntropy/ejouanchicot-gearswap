---============================================================================
--- FFXI GearSwap Configuration - Blue Mage (BLU) - Modular Architecture
---============================================================================
--- Loader for the Blue Mage job: Mote-Include, the shared systems, the BLU
--- hook modules and this character's configs and sets.
---
--- @file shared/entry/blu.lua
--- @author ejouanchicot
--- @version 1.0
--- @date Created: 2026-09-26
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Architecture:
---   EntryKit.job >> load_job >> Hooks >> Logic Modules
---
--- Hooks Modules:
---   BLU_PRECAST | BLU_MIDCAST | BLU_AFTERCAST | BLU_STATUS | BLU_BUFFS
---   BLU_IDLE | BLU_ENGAGED | BLU_COMMANDS
---
--- Logic Modules:
---   logic/spell_map.lua        - Blue Magic spell -> gear category
---   logic/set_builder.lua      - Idle / engaged sets, single wield
---   logic/unbridled.lua        - Unbridled Learning first (option)
---   logic/expiacion_guard.lua  - Expiacion held for Aftermath Lv.3 (option)
---   logic/azure_sets.lua       - AzureSets addon while on BLU
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with BLU's AzureSets (its Blue Magic spell lists)
local try_require = require('shared/utils/core/try_require')

require('shared/utils/core/entry_kit').job('BLU', {
    -- the spell lists while on BLU
    after_setup = function()
        local AzureSets = try_require('shared/jobs/blu/functions/logic/azure_sets')
        if AzureSets then AzureSets.load() end
    end,
    unload = function()
        local AzureSets = try_require('shared/jobs/blu/functions/logic/azure_sets')
        if AzureSets then AzureSets.unload() end
    end,
})
