---============================================================================
--- FFXI GearSwap Configuration - Geomancer (GEO) - Modular Architecture
---============================================================================
--- Advanced Geomancer job configuration built on modular architecture principles.
--- This file serves as the main coordinator, delegating all specialized logic
--- to dedicated modules for maximum maintainability and scalability.
---
--- @file shared/entry/geo.lua
--- @author ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date Created: 2025-10-09
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Key Features:
---   - Modular architecture with specialized function modules
---   - Geomancy spell system (Indi/Geo bubble management)
---   - Luopan (pet) survival gear optimization
---   - Entrust ability support
---   - Handbell instrument management
---   - PetTP addon loaded on GEO, unloaded on file_unload
---
--- Architecture Overview:
---   EntryKit.job >> load_job >> Specialized Modules
---
--- Module Organization:
---   ├── <Character>/geo/sets/geo_sets.lua [Equipment Sets]
---   └── functions/GEO_*.lua            [Specialized Modules]
---
--- Specialized Modules:
---   GEO_PRECAST | GEO_MIDCAST | GEO_AFTERCAST | GEO_STATUS | GEO_BUFFS
---   GEO_IDLE | GEO_ENGAGED | GEO_COMMANDS
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with GEO's PetTP addon and its stand-behind run
require('shared/utils/core/entry_kit').job('GEO', {
    -- PetTP for Luopan management (pettp = false in _common/tools/ADDONS_CONFIG.lua: left alone). The flag lives on
    -- `windower`, which outlives the job sandbox: a subjob change or //gs reload of GEO sends neither the unload nor
    -- the load again (same pattern as BLU, shared/jobs/blu/functions/logic/azure_sets.lua). PetTP handles its own
    -- messages.
    after_states = function()
        if not windower._geo_pettp_loaded then
            windower._geo_pettp_loaded = require('shared/utils/core/job_addons').run('load', 'pettp')
        end
    end,
    unload = function(next_file)
        -- //gs c behind: a run under way stops here, or nothing would ever stop it (logic/stand_behind.lua)
        pcall(function() require('shared/jobs/geo/functions/logic/stand_behind').unload() end)
        if not windower._geo_pettp_loaded then return end
        local function unload_pettp()
            windower._geo_pettp_loaded = nil
            windower.send_command('lua unload pettp')
        end
        if next_file == nil then
            -- GearSwap itself is unloading: no later check would ever run
            unload_pettp()
        else
            -- GearSwap still reports the old job here, and the next file may be GEO again (subjob change,
            -- //gs reload): ask the game 2 s later. Only windower.* in this coroutine: it runs after the sandbox is
            -- gone.
            coroutine.schedule(function()
                local me = windower.ffxi.get_player()
                if me and me.main_job == 'GEO' then return end
                unload_pettp()
            end, 2)
        end
    end,
})
