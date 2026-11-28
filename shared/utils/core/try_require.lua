---============================================================================
--- try_require - a module the caller can do without
---============================================================================
--- try_require(name) is the module, or nil when it does not load (missing, or
--- an error in it or in one of its dependencies). For a module whose absence
--- the caller handles: the error itself is dropped, so a caller that must say
--- why something failed keeps its own pcall(require, ...) (EntryKit's keybinds).
--- A character's own files go through CharPaths.optional / CharPaths.load.
---
---   local try_require = require('shared/utils/core/try_require')
---   local AmpullaLock = try_require('shared/utils/equipment/ampulla_lock')
---   if AmpullaLock then AmpullaLock.release() end
---
--- @file    shared/utils/core/try_require.lua
---============================================================================

--- @param name string The module's require path
--- @return table|nil The module, nil when it does not load
return function(name)
    local ok, module = pcall(require, name)
    if ok then return module end
    return nil
end
