---============================================================================
--- FFXI GearSwap Configuration - Beastmaster (BST) - Modular Architecture
---============================================================================
--- Main file for Beastmaster job with dynamic ecosystem/species/ammoSet states.
--- CRITICAL: Uses dynamic state recreation for species and ammoSet.
---
--- @file shared/entry/bst.lua
--- @author ejouanchicot
--- @version 1.0.0 - Initial Release
--- @date Created: 2025-10-17
--- @requires Windower FFXI, GearSwap addon, Mote-Include v2.0+
---============================================================================

-- get_sets, init_gear_sets, user_setup, job_sub_job_change, job_update and file_unload: the same for every job
-- (shared/utils/core/entry_kit.lua), with BST's pet data (before Mote-Include, so user_setup has it), its ecosystems, the bst-hud
-- addon and the pet monitor
local CharPaths = require('shared/utils/core/char_paths')
local try_require = require('shared/utils/core/try_require')

local monitor_event_id = nil
local last_check = 0
local prev_pet_eng = 'false'
-- The monitor runs every second: an error is shown once per load, not every run
local monitor_error_shown = false

-- Upvalues for hot path (prerender fires ~60fps)
local os_clock = os.clock
local get_mob = windower.ffxi.get_mob_by_target
local get_player = windower.ffxi.get_player

--- Register the prerender monitor (no-op if already registered).
--- Called through _G.start_pet_monitoring from user_setup() (after 3s)
--- and from BST_AFTERCAST.lua.
--- @return void
local function start_pet_monitoring()
    if monitor_event_id then return end

    monitor_event_id = windower.raw_register_event('prerender', function()
        local now = os_clock()
        if now - last_check < 1.0 then return end
        last_check = now

        local ok, err = pcall(function()
            local pet = get_mob('pet')
            local pet_eng_val = 'false'

            if pet and pet.id and pet.id ~= 0 then
                local pet_fighting = (pet.status == 1)
                pet_eng_val = pet_fighting and 'true' or 'false'

                -- Auto-engage: player fighting + pet idle + auto on
                if not pet_fighting
                    and not _G.bst_rdymove_active
                    and state.AutoPetEngage
                    and state.AutoPetEngage.value == 'On'
                then
                    local lp = get_player()
                    if lp and lp.status == 1 then
                        windower.send_command('input /pet "Fight" <t>')
                    end
                end
            end

            -- Update petEngaged state + gear refresh (only on change)
            if state.PetEngaged and state.PetEngaged.value ~= pet_eng_val then
                state.PetEngaged:set(pet_eng_val)
            end
            local sent_update = pet_eng_val ~= prev_pet_eng
            if sent_update then
                if _G.LagDebugger then _G.LagDebugger.on_prerender_check(pet_eng_val, prev_pet_eng, true) end
                windower.send_command('gs c update')
                prev_pet_eng = pet_eng_val
            end
        end)

        if not ok then
            pcall(function() require('shared/utils/debug/trace_log').log('BST', 'monitor error: %s', tostring(err)) end)
            if not monitor_error_shown then
                monitor_error_shown = true
                local MessageFormatter = try_require('shared/utils/messages/message_formatter')
                if MessageFormatter then
                    MessageFormatter.show_error('[BST] Pet monitor error: ' .. tostring(err))
                end
            end
        end
    end)
end

--- Unregister the prerender monitor. Called from file_unload().
--- @return void
local function stop_pet_monitoring()
    if monitor_event_id then
        windower.unregister_event(monitor_event_id)
        monitor_event_id = nil
    end
end

_G.start_pet_monitoring = start_pet_monitoring
_G.stop_pet_monitoring = stop_pet_monitoring

require('shared/utils/core/entry_kit').job('BST', {
    before_mote = function()
        _G.BSTBeastPetData = require(CharPaths.module('job', 'BST_PET_DATA', 'BST'))
        local eco_ok, eco_data = CharPaths.load('job', 'BST_ECOSYSTEM_DATA', 'BST')
        _G.BSTEcosystemData = eco_ok and eco_data or nil
    end,
    after_states = function()
        local EcosystemManager = try_require('shared/jobs/bst/functions/logic/ecosystem_manager')
        if EcosystemManager then
            EcosystemManager.initialize()
        else
            local MessageFormatter = try_require('shared/utils/messages/message_formatter')
            if MessageFormatter then
                MessageFormatter.show_error('[BST] Failed to load EcosystemManager')
            end
        end
    end,
    after_setup = function()
        -- the HUD, for EcosystemManager's refresh after an ecosystem / species change
        _G.KeybindUI = try_require('shared/utils/ui/UI_MANAGER')
        -- bst-hud reloaded 2 s later: a counter drops a load a newer reload or file_unload replaced
        _G.bst_hud_load_id = (_G.bst_hud_load_id or 0) + 1
        local my_hud_id = _G.bst_hud_load_id
        coroutine.schedule(function()
            -- Guard 1: Counter (invalidated by newer reload or file_unload)
            if _G.bst_hud_load_id ~= my_hud_id then return end
            -- Guard 2: Only load if still on BST (handles main job change)
            if player and player.main_job ~= 'BST' then return end
            -- Guard 3: bst-hud = false in _common/tools/ADDONS_CONFIG.lua
            local JobAddons = require('shared/utils/core/job_addons')
            if not JobAddons.allowed('bst-hud') then return end
            -- Guard 4: Always unload first, then load after delay
            windower.send_command('lua unload bst-hud')
            coroutine.schedule(function()
                if _G.bst_hud_load_id ~= my_hud_id then return end
                if player and player.main_job ~= 'BST' then return end
                windower.send_command('lua load bst-hud')
            end, 1.5)
        end, 2.0)
        -- The pet monitor (pet engaged status + auto-engage), 3 s later (let UI/keybinds load first). Runs with or
        -- without a pet; the monitor skips the pet checks when none.
        coroutine.schedule(function()
            if player and player.main_job ~= 'BST' then return end
            if not _G.start_pet_monitoring then return end
            start_pet_monitoring()
        end, 3.0)
    end,
    unload = function()
        stop_pet_monitoring()
        _G.bst_hud_load_id = (_G.bst_hud_load_id or 0) + 1
        -- Unload BST HUD addon (unless ADDONS_CONFIG.lua leaves it alone)
        require('shared/utils/core/job_addons').run('unload', 'bst-hud')
        -- Clear exported globals
        _G.KeybindUI = nil
        _G.start_pet_monitoring = nil
        _G.stop_pet_monitoring = nil
    end,
})
