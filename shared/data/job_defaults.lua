---============================================================================
--- Job defaults - the macro book and lockstyle a job falls back to
---============================================================================
--- What a job uses when the character's <JOB>_MACROBOOK.lua / <JOB>_LOCKSTYLE.lua
--- has no entry for the subjob in play: the subjob taken when there is none,
--- the lockstyle set and the macro book / page. Read by LockstyleManager.install,
--- MacrobookManager.install and the Atelier export (atelier_export.lua).
---
--- A job not listed, or a value left out, takes DEFAULT.
---
--- @file    shared/data/job_defaults.lua
---============================================================================
local DEFAULT = {lockstyle = 1, book = 1, page = 1}

local JOBS = {
    BLM = {subjob = 'SAM'}, BLU = {subjob = 'WAR'}, BRD = {subjob = 'WHM'}, BST = {subjob = 'SAM'},
    COR = {subjob = 'SAM'}, DNC = {subjob = 'SAM'}, DRG = {subjob = 'SAM'}, DRK = {subjob = 'SAM'},
    GEO = {subjob = 'SAM'}, MNK = {subjob = 'WAR'}, NIN = {subjob = 'WAR'}, PLD = {subjob = 'SAM'},
    PUP = {subjob = 'WAR'}, RDM = {subjob = 'NIN'}, RNG = {subjob = 'WAR'}, RUN = {subjob = 'SAM'},
    SAM = {subjob = 'SAM'}, SCH = {subjob = 'RDM'}, SMN = {subjob = 'WHM'}, THF = {subjob = 'SAM'},
    WAR = {subjob = 'SAM', lockstyle = 4, book = 22}, WHM = {subjob = 'SAM'},
}

local JobDefaults = {}

--- A job's defaults: {subjob, lockstyle, book, page}.
--- @param job string Job code ('WAR')
--- @return table
function JobDefaults.get(job)
    local own = JOBS[job] or {}
    return {
        subjob = own.subjob,
        lockstyle = own.lockstyle or DEFAULT.lockstyle,
        book = own.book or DEFAULT.book,
        page = own.page or DEFAULT.page,
    }
end

return JobDefaults
