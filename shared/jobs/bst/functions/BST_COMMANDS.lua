---  ═══════════════════════════════════════════════════════════════════════════
---   BST Commands Module - Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific commands for Beastmaster:
---   • ecosystem - Cycle state.Ecosystem (rebuilds species / ammoSet)
---   • species - Cycle through species for current ecosystem
---   • broth - Display broth counts in inventory
---   • pet engage - Manually engage pet
---   • pet disengage - Manually disengage pet
---   • rdylist - List all available Ready Moves with index numbers
---   • rdymove [N] - Execute Ready Move by index (Fight first if the pet is idle)
---   • debugprecast - Toggle BST precast debug (answers before the common
---     command of the same name)
---   • debugmidcast, cyclestate, dual-box, UI / watchdog / common commands
---
---   Uses centralized MessageFormatter for all messages (professional multi-color).
---
---   @file    shared/jobs/bst/functions/BST_COMMANDS.lua
---   @author  ejouanchicot
---   @version 2.0
---   @date    Created: 2025-10-17
---   @date    Updated: 2025-10-18 - Standardized all messages with MessageFormatter
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES
---  ═══════════════════════════════════════════════════════════════════════════
local JobCommands = require('shared/utils/core/job_commands')
-- a handler that returns PASS leaves the word unanswered (JobCommands.router)
local PASS = JobCommands.PASS

local try_require = require('shared/utils/core/try_require')
local MessageFormatter = require('shared/utils/messages/message_formatter')
local EcosystemManager = try_require('shared/jobs/bst/functions/logic/ecosystem_manager')
if not EcosystemManager then MessageFormatter.show_error_module_not_loaded('EcosystemManager') end
local PetManager = try_require('shared/jobs/bst/functions/logic/pet_manager')
if not PetManager then MessageFormatter.show_error_module_not_loaded('PetManager') end

---  ═══════════════════════════════════════════════════════════════════════════
---   BROTH COUNT DISPLAY
---  ═══════════════════════════════════════════════════════════════════════════

---   Display broth counts in inventory
---   @return void
local function display_broth_count()
    -- Load resources for item lookup
    local res = require('resources')

    -- Get player items
    local items = windower.ffxi.get_items()
    if not items or not items.inventory then
        MessageFormatter.show_error('Cannot access inventory')
        return
    end

    -- Collect broth counts
    local broth_counts = {}
    for slot = 1, items.max_inventory do
        local item = items.inventory[slot]
        if item and item.id ~= 0 then
            local item_name = res.items[item.id] and res.items[item.id].en or "Unknown"
            if item_name:find("Broth") then
                broth_counts[item_name] = (broth_counts[item_name] or 0) + item.count
            end
        end
    end

    MessageFormatter.show_bst_broth_list(broth_counts)
end

-- Numbers each rdymove sequence: only the latest one clears the pause flag
-- or sends Heel, so an earlier sequence ending cannot let the auto-engage
-- loop send Fight (or recall the pet) in the middle of a newer one.
local rdymove_seq = 0

---   True when the game reports the player engaged right now (player.status
---   would be the value captured when the command was typed)
---   @return boolean
local function player_engaged_now()
    local p = windower.ffxi.get_player()
    return p ~= nil and p.status == 1
end

---   Fight, then the Ready move 3.5 s later, then Heel at 6 s when asked.
---   _G.bst_rdymove_active pauses the BST entry file's pet auto-engage loop
---   meanwhile. Every delayed step goes through LoadGate: a reload or a job
---   change in between drops it.
---   @param move_name string Ready move to use
---   @param heel boolean Recall the pet afterwards (player was idle)
---   @return void
local function run_rdymove_sequence(move_name, heel)
    local LoadGate = require('shared/utils/core/load_gate')
    rdymove_seq = rdymove_seq + 1
    local my_seq = rdymove_seq
    _G.bst_rdymove_active = true

    send_command('input /pet "Fight" <stnpc>')
    LoadGate.defer(3.5, function()
        send_command('input /pet "' .. move_name .. '" <me>')
    end, 'bst_rdymove_move')

    if heel then
        LoadGate.defer(6, function()
            -- The player may have engaged since the command: the pet then
            -- stays in the fight
            if my_seq == rdymove_seq and not player_engaged_now() then
                send_command('input /pet "Heel" <me>')
            end
        end, 'bst_rdymove_heel')
    end

    LoadGate.defer(heel and 6.5 or 4.5, function()
        if my_seq == rdymove_seq then _G.bst_rdymove_active = false end
    end, 'bst_rdymove_done')
end

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HOOK
---  ═══════════════════════════════════════════════════════════════════════════

job_self_command = JobCommands.router('BST', {
    first = {
        debugprecast = function()
            -- Toggle BST-specific precast debug (for Job Abilities)
            -- Universal system only handles Magic, BST needs JA debug
            _G.BST_DEBUG_PRECAST = not _G.BST_DEBUG_PRECAST

            local status = _G.BST_DEBUG_PRECAST and "ON" or "OFF"
            MessageFormatter.show_success("BST Precast Debug (JA): " .. status)

        end,
    },
    words = {
        -- Ecosystem commands
        ecosystem = function()
            if not EcosystemManager then
                MessageFormatter.show_error_module_not_loaded('EcosystemManager')
                return PASS
            end
            EcosystemManager.change_ecosystem()
        end,
        species = function()
            if not EcosystemManager then
                MessageFormatter.show_error_module_not_loaded('EcosystemManager')
                return PASS
            end
            EcosystemManager.change_species()
        end,
        broth = display_broth_count, broths = display_broth_count,
        -- Pet commands
        pet = function(cmdParams)
            if #cmdParams < 2 then
                MessageFormatter.show_info('Usage: //gs c pet [engage|disengage]')
                return
            end

            local pet_command = cmdParams[2]:lower()

            if pet_command == 'engage' or pet_command == 'disengage' then
                if not PetManager then
                    MessageFormatter.show_error_module_not_loaded('PetManager')
                    return PASS
                end
                if pet_command == 'engage' then PetManager.engage_pet() else PetManager.disengage_pet() end
                return
            end

            MessageFormatter.show_error('Unknown pet command: ' .. pet_command)
        end,
        -- Ready move commands (rdymove 1-6, rdylist)
        rdylist = function()
            if not PetManager then
                MessageFormatter.show_error_module_not_loaded('PetManager')
                return
            end

            -- Check if pet exists
            local pet = _G.pet
            if not pet or not pet.id or pet.id == 0 then
                MessageFormatter.show_error_no_pet()
                return
            end

            -- Get ready moves list
            local ready_moves = PetManager.get_ready_moves()

            if not ready_moves or #ready_moves == 0 then
                MessageFormatter.show_error_no_ready_moves()
                return
            end

            MessageFormatter.show_bst_ready_moves_list(pet.name, ready_moves)
        end,
        rdymove = function(cmdParams)
            if not PetManager then
                MessageFormatter.show_error_module_not_loaded('PetManager')
                return
            end

            -- Check if index provided
            if #cmdParams < 2 then
                MessageFormatter.show_info('Usage: //gs c RdyMove [1-6]')
                return
            end

            -- Parse index
            local index = tonumber(cmdParams[2])
            if not index or index < 1 then
                MessageFormatter.show_error_invalid_index(cmdParams[2])
                return
            end

            -- Check if pet exists
            local pet = _G.pet
            if not pet or not pet.id or pet.id == 0 then
                MessageFormatter.show_error_no_pet()
                return
            end

            -- Get ready moves list
            local ready_moves = PetManager.get_ready_moves()
            if not ready_moves or #ready_moves == 0 then
                MessageFormatter.show_error_no_ready_moves()
                return
            end

            -- Check if index is valid
            if index > #ready_moves then
                MessageFormatter.show_error_index_out_of_range(index, #ready_moves)
                return
            end

            -- Get the move
            local move = ready_moves[index]
            if not move or not move.name then
                MessageFormatter.show_error('Invalid Ready Move at index ' .. index)
                return
            end

            -- Check pet and player engagement status
            local pet_engaged = (pet.status == 1 or pet.status == "Engaged")
            local player_engaged = (player and player.status == "Engaged")

            -- Capture move name in local variable for coroutine closure
            local move_name = move.name

            if pet_engaged then
                -- Pet is already fighting - just use the Ready Move
                MessageFormatter.show_bst_ready_move_use(index, move_name)
                send_command('input /pet "' .. move_name .. '" <me>')
            else
                -- Pet is idle - check if player is engaged
                if player_engaged then
                    -- Player engaged + Pet idle >> Fight + Ready Move (NO Heel)
                    MessageFormatter.show_bst_ready_move_auto_engage(index, move_name)
                    run_rdymove_sequence(move_name, false)
                else
                    -- Player idle + Pet idle >> Fight + Ready Move + Heel
                    MessageFormatter.show_bst_ready_move_auto_sequence(index, move_name)
                    run_rdymove_sequence(move_name, true)
                end
            end

        end,
    },
})

--- BST adds nothing of its own: the shared handler is the whole
--- behaviour. Pass a function to state_change() to extend it.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export globally for GearSwap
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change

