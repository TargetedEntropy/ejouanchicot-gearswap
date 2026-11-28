---  ═══════════════════════════════════════════════════════════════════════════
---   THF Functions - what THF does besides its hook files
---  ═══════════════════════════════════════════════════════════════════════════
---   Loaded by EntryKit.load_job_files after the THF hook files
---   (shared/utils/core/entry_kit.lua, JOB_FILES `own`).
---
---   @file    shared/jobs/thf/functions/thf_functions.lua
---   @author  ejouanchicot
---  ═══════════════════════════════════════════════════════════════════════════

-- TreasureMode tag tracking: its events die with each load, so register here
local TreasureHunter = require('shared/jobs/thf/functions/logic/treasure_hunter')
TreasureHunter.init()
