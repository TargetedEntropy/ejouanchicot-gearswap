---  ═══════════════════════════════════════════════════════════════════════════
---   WAR Precast Module - Precast Action Handling & Cooldown Monitoring
---  ═══════════════════════════════════════════════════════════════════════════
---   Handles all precast actions for Warrior job:
---   • Weaponskills preparation & TP gear optimization
---   • Cooldown check for abilities and spells
---   • Security layers (debuff guard, range checks, validation)
---   Job ability and Fast Cast sets are left to Mote-Include.
---
---   **PERFORMANCE OPTIMIZATION:**
---   • Lazy-loaded: All modules loaded on first action
---
---   @file    shared/jobs/war/functions/WAR_PRECAST.lua
---   @author  ejouanchicot
---   @version 2.1 - Lazy Loading for performance
---   @date    Created: 2025-09-29 | Updated: 2025-11-15
---   @requires PrecastPipeline
---  ═══════════════════════════════════════════════════════════════════════════

local PrecastPipeline = require('shared/utils/precast/precast_pipeline')

---  ═══════════════════════════════════════════════════════════════════════════
---   PRECAST HOOKS
---  ═══════════════════════════════════════════════════════════════════════════

--- guard >> cooldown >> weaponskill in PrecastPipeline's order, with this job's own steps;
--- the TP pieces after the set (shared/utils/precast/precast_pipeline.lua)
job_precast, job_post_precast = PrecastPipeline.hooks('WAR')

---  ═══════════════════════════════════════════════════════════════════════════
---   MODULE EXPORT
---  ═══════════════════════════════════════════════════════════════════════════

-- Export globally for GearSwap
_G.job_precast = job_precast
_G.job_post_precast = job_post_precast

-- Module table for require() compatibility (parity with _G exports above)
return {
    job_precast = job_precast,
    job_post_precast = job_post_precast,
}

