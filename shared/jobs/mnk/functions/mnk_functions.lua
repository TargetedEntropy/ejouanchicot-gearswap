---  ═══════════════════════════════════════════════════════════════════════════
---   MNK Functions Facade - Module Loader
---  ═══════════════════════════════════════════════════════════════════════════
---   Loads the Monk hook modules in dependency order and wires them into
---   Mote-Include's globals.
---
---   Architecture:
---   • Hook modules (11): PRECAST, MIDCAST, AFTERCAST, IDLE, ENGAGED, STATUS,
---     BUFFS, COMMANDS
---   • Logic modules (2, required by the hooks):
---       logic/buff_layers.lua  Impetus / Footwork / Hundred Fists /
---                              Counterstance sets on engaged, Impetus /
---                              Footwork layers on weaponskills
---       logic/set_builder.lua  idle / engaged sets: town, Hybrid Mode,
---                              Offense Mode, buff layers, weapon, movement
---
---   @file    shared/jobs/mnk/functions/mnk_functions.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2026-09-29
---  ═══════════════════════════════════════════════════════════════════════════

local Profiler = require('shared/utils/debug/performance_profiler')
local TIMER = Profiler.create_timer('MNK')

include('../shared/utils/messages/formatters/magic/message_buffs.lua')  -- Buff gain/loss messages
TIMER('message_buffs')

-- Combat action hooks
include('../shared/jobs/mnk/functions/MNK_PRECAST.lua')   -- Guard, cooldown, WS, Impetus / Footwork WS layers
TIMER('MNK_PRECAST')
include('../shared/jobs/mnk/functions/MNK_MIDCAST.lua')   -- Subjob magic via MidcastManager
TIMER('MNK_MIDCAST')
include('../shared/jobs/mnk/functions/MNK_AFTERCAST.lua') -- Watchdog tick
TIMER('MNK_AFTERCAST')

-- Gear selection hooks
include('../shared/jobs/mnk/functions/MNK_IDLE.lua')      -- Town, Hybrid Mode idle, weapon, movement
TIMER('MNK_IDLE')
include('../shared/jobs/mnk/functions/MNK_ENGAGED.lua')   -- Offense / Hybrid Mode, buff layers, weapon
TIMER('MNK_ENGAGED')

-- Event hooks
include('../shared/jobs/mnk/functions/MNK_STATUS.lua')    -- Status change (Doom slots)
TIMER('MNK_STATUS')
include('../shared/jobs/mnk/functions/MNK_BUFFS.lua')     -- Doom, buff layers rebuilt on gain / loss
TIMER('MNK_BUFFS')

-- Lockstyle and macro book: the shared managers set up for this job (shared/data/job_defaults.lua)
require('shared/utils/lockstyle/lockstyle_manager').install('MNK')
require('shared/utils/macrobook/macrobook_manager').install('MNK')
include('../shared/jobs/mnk/functions/MNK_COMMANDS.lua')  -- Commands, state change hook
TIMER('MNK_COMMANDS')

-- Dual-boxing manager (deferred init + lazy message loading)
require('shared/utils/dualbox/dualbox_manager')

local MessageFormatter = require('shared/utils/messages/message_formatter')
MessageFormatter.show_debug('MNK', 'All functions loaded successfully')

TIMER('TOTAL MNK_functions', true)
