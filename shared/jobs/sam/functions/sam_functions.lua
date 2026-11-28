---  ═══════════════════════════════════════════════════════════════════════════
---   SAM Functions Facade - Module Loader
---  ═══════════════════════════════════════════════════════════════════════════
---   Loads all SAM-specific function modules in correct order.
---   @file    shared/jobs/sam/functions/sam_functions.lua
---   @author  ejouanchicot
---   @version 1.0
---   @date    Created: 2025-10-21
---  ═══════════════════════════════════════════════════════════════════════════

-- Load all modules in dependency order
-- ═══════════════════════════════════════════════════════════════════
-- PERFORMANCE PROFILING (Toggle with: //gs c perf start)
-- ═══════════════════════════════════════════════════════════════════
local Profiler = require('shared/utils/debug/performance_profiler')
local TIMER = Profiler.create_timer('SAM')
-- ═══════════════════════════════════════════════════════════════════

-- Lockstyle and macro book: the shared managers set up for this job (shared/data/job_defaults.lua)
require('shared/utils/lockstyle/lockstyle_manager').install('SAM')
require('shared/utils/macrobook/macrobook_manager').install('SAM')
include('../shared/jobs/sam/functions/SAM_PRECAST.lua')
TIMER('SAM_PRECAST')
include('../shared/jobs/sam/functions/SAM_MIDCAST.lua')
TIMER('SAM_MIDCAST')
include('../shared/jobs/sam/functions/SAM_AFTERCAST.lua')
TIMER('SAM_AFTERCAST')
include('../shared/jobs/sam/functions/SAM_IDLE.lua')
TIMER('SAM_IDLE')
include('../shared/jobs/sam/functions/SAM_ENGAGED.lua')
TIMER('SAM_ENGAGED')
include('../shared/jobs/sam/functions/SAM_STATUS.lua')
TIMER('SAM_STATUS')
include('../shared/jobs/sam/functions/SAM_BUFFS.lua')
TIMER('SAM_BUFFS')
include('../shared/jobs/sam/functions/SAM_COMMANDS.lua')
TIMER('SAM_COMMANDS')

-- Load dual-boxing manager (uses deferred init + lazy message loading)
require('shared/utils/dualbox/dualbox_manager')

local MessageFormatter = require('shared/utils/messages/message_formatter')
MessageFormatter.show_debug('SAM', 'Functions loaded successfully')

-- ═══════════════════════════════════════════════════════════════════
TIMER('TOTAL SAM_functions', true)
-- ═══════════════════════════════════════════════════════════════════
