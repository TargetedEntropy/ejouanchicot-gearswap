---============================================================================
--- FFXI GearSwap Configuration - Dancer (DNC) - Modular Architecture
---============================================================================
--- Advanced Dancer job configuration built on modular architecture principles.
--- This file serves as the main coordinator, delegating all specialized logic
--- to dedicated modules for maximum maintainability and scalability.
---
--- @file    shared/entry/dnc.lua
--- @author  ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date    Created: 2025-10-04
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---
--- Features:
---   • Modular architecture (hook modules + 5 logic modules)
---   • DPS-focused gear automation with survival modes (PDT/Normal)
---   • Step management system (Quickstep, Box Step rotation)
---   • Climactic Flourish auto-trigger for weaponskills
---   • Jump auto-trigger (DRG subjob support)
---   • Waltz healing system with HP-based tier selection
---   • TP bonus optimization (Moonshade Earring automation)
---   • Weapon management (Mpu Gandring, Demersal Degen)
---   • JobChangeManager integration (anti-collision on job switches)
---   • Keybind system with subjob filtering
---   • UI display with real-time state tracking
---   • Smart lockstyle/macrobook per subjob
---
--- Architecture Overview:
---   EntryKit.job >> EntryKit.load_job_files >> Hooks + 5 Logic Modules
---
--- Module Organization:
---   ├── <Character>/dnc/sets/dnc_sets.lua [Equipment Sets]
---   ├── functions/DNC_*.lua                [Hook Modules]
---   └── functions/logic/*.lua              [5 Logic Modules]
---
--- Hook Modules (11):
---   DNC_PRECAST | DNC_MIDCAST | DNC_AFTERCAST | DNC_IDLE | DNC_ENGAGED
---   DNC_STATUS | DNC_BUFFS | DNC_COMMANDS
---
--- Logic Modules (5):
---   climactic_manager | set_builder | smartbuff_manager
---   step_manager | ws_variant_selector
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with DNC's WS configuration and its cancel_conflicting_buffs
local CharPaths = require('shared/utils/core/char_paths')

require('shared/utils/core/entry_kit').job('DNC', {
    configs = function()
        _G.DNCWSConfig = require(CharPaths.module('job', 'DNC_WS_CONFIG', 'DNC'))
        -- Override Mote's cancel_conflicting_buffs to disable native cooldown/recast checks
        -- (CooldownChecker handles recast messages with better formatting)
        -- BUT keep buff cancellation for Spectral Jig/Sneak/Stoneskin
        -- NOTE: Utsusemi shadows handled by utsusemi_shadows.lua (every job,
        --       via init_spell_messages), Waltz/Samba dance cancels skipped
        --       to preserve DNC set variants (SaberDance/FanDance gear sets)
        _G.cancel_conflicting_buffs = function(spell, action, spellMap, eventArgs)
            if spell.english == 'Spectral Jig' and buffactive.sneak then
                cast_delay(0.2)
                send_command('cancel sneak')
            elseif spell.english == 'Sneak' and spell.target.type == 'SELF' and buffactive.sneak then
                send_command('cancel sneak')
            elseif spell.english == 'Stoneskin' then
                send_command('@wait 1.0;cancel stoneskin')
            end
        end
    end,
})
