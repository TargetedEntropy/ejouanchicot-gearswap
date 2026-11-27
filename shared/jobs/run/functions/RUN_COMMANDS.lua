---  ═══════════════════════════════════════════════════════════════════════════
---   RUN Commands - Custom Command Handling
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles job-specific custom commands for Rune Fencer job:
---   • Common commands (reload, checksets, waltz, jump, etc.)
---   • UI commands (toggle, update, reload UI)
---   • RUN-specific commands (aoe, rune)
---   • State change UI synchronization
---
---   Uses centralized command handlers for consistency across all jobs.
---
---   @file    shared/jobs/run/functions/RUN_COMMANDS.lua
---   @author  ejouanchicot
---   @version 3.0.0 - Logic Extracted to logic/
---   @date    Created: 2025-10-03 | Updated: 2025-10-06
---   @requires shared/utils/ui/UI_COMMANDS, shared/utils/core/COMMON_COMMANDS
---  ═══════════════════════════════════════════════════════════════════════════

---  ═══════════════════════════════════════════════════════════════════════════
---   DEPENDENCIES - LAZY LOADING (Performance Optimization)
---  ═══════════════════════════════════════════════════════════════════════════
-- Command handlers loaded on first command
local UICommands = nil
local CommonCommands = nil
local WatchdogCommands = nil
local CycleHandler = nil
local MessageCommands = nil

-- RUN logic modules
local AOEManager = nil
local RuneManager = nil

local function ensure_commands_loaded()
    if not UICommands then
        UICommands = require('shared/utils/ui/UI_COMMANDS')
        CommonCommands = require('shared/utils/core/COMMON_COMMANDS')
        WatchdogCommands = require('shared/utils/core/WATCHDOG_COMMANDS')
        CycleHandler = require('shared/utils/core/CYCLE_HANDLER')
        MessageCommands = require('shared/utils/messages/formatters/ui/message_commands')

        -- RUN logic modules
        AOEManager = require('shared/jobs/run/functions/logic/aoe_manager')
        RuneManager = require('shared/jobs/run/functions/logic/rune_manager')
    end
end

local JobCommands = require('shared/utils/core/job_commands')

---  ═══════════════════════════════════════════════════════════════════════════
---   COMMAND HANDLER HOOK
---  ═══════════════════════════════════════════════════════════════════════════

---   Handle job-specific self commands
---   Processes commands in order: aoe (it must win over the common aoe) >>
---   JobCommands.shared (watchdog >> dual-box >> common >> UI >>
---   debugmidcast >> cyclestate) >> RUN-specific
---
---   Common commands:
---   • reload         - Reload GearSwap
---   • checksets      - Validate equipment sets
---   • waltz <target> - Perform waltz on target
---   • jump           - Use DRG subjob Jump
---
---   UI commands:
---   • ui             - Toggle UI visibility
---
---   RUN-specific commands:
---   • aoe            - Execute Blue Magic AOE spell rotation (RUN/BLU)
---   • rune           - Execute the rune selected in state.RuneMode
---
---   @param cmdParams table Command parameters array (e.g., {"aoe"})
---   @param eventArgs table Event arguments with handled flag
---   @return void
function job_self_command(cmdParams, eventArgs)
    if not cmdParams[1] then
        return
    end

    -- Lazy load command handlers on first command
    ensure_commands_loaded()

    local command = cmdParams[1]:lower()

    -- AOE: the bare word runs the Blue Magic rotation (RUN/BLU). Ahead of
    -- the common commands, which answer `aoe sneak|invi|erase` (/SCH)
    if command == 'aoe' and not cmdParams[2] then
        if AOEManager then
            AOEManager.execute_aoe()
            eventArgs.handled = true
        end
        return
    end

    if JobCommands.shared(command, cmdParams, eventArgs, 'RUN') then return end

    -- ══════════════════════════════════════════════════════════════════════════
    -- RUN-SPECIFIC COMMANDS
    -- ══════════════════════════════════════════════════════════════════════════

    -- Rune: cast the rune selected in state.RuneMode
    if command == 'rune' then
        if RuneManager then
            RuneManager.execute_rune()
            eventArgs.handled = true
        end
        return
    end
end

---  ═══════════════════════════════════════════════════════════════════════════
---   STATE CHANGE HOOK
---  ═══════════════════════════════════════════════════════════════════════════

--- RUN adds nothing of its own: the shared handler is the whole
--- behaviour. Pass a function to state_change() to extend it.
local LifecycleManager = require('shared/utils/core/lifecycle_manager')

job_state_change = LifecycleManager.state_change()

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export globally for GearSwap
_G.job_self_command = job_self_command
_G.job_state_change = job_state_change
