---============================================================================
--- Action Hooks - the layers laid on Mote's gear functions, in one order
---============================================================================
--- Mote routes every gear decision through three functions it defines after
--- user_setup(): handle_equipping_gear(status, pet_status),
--- cleanup_precast(spell, spellMap, eventArgs) and cleanup_midcast(spell,
--- spellMap, eventArgs). Several systems add their work around them (the belt,
--- Dual Wield, Treasure Hunter, the midcast fallback, the player's custom
--- states, the cast time, the Combat Mode lock). Each one registers a layer
--- here, and install() wraps each function once:
---
---   ORDER (inner first)  each later layer is around the earlier ones
---
--- A layer is {before = fn(...), after = fn(token, ...)}: before runs ahead of
--- the inner call (and may return a token), after runs once the inner call has
--- returned (and gets the token). Both run under pcall: an error in one layer
--- is traced and named once in chat, and never stops the other layers or the
--- gear itself (each layer used to wrap the function by hand, some with no
--- pcall, so one error aborted every layer outside it).
---
--- The layers live on the sandbox _G: a reload builds a new _G, Mote defines
--- its three functions again, and the chain is built again, once.
---
--- @file    shared/utils/core/action_hooks.lua
---============================================================================
local ActionHooks = {}

--- The chain, innermost first: within one event the last equip() of a slot wins and a locked slot refuses every
--- equip(), so the job's set goes on first (Mote), the automatic overlays next, the player's custom gear after them,
--- and the Combat Mode lock is outermost (set before any gear goes on). The midcast fallback routes a subjob spell
--- before the belt, the cast time reads what the precast finally sends.
ActionHooks.ORDER = {
    elemental_belt = 10,     -- cleanup_precast, cleanup_midcast: before
    dual_wield = 20,         -- handle_equipping_gear: after
    treasure_hunter = 30,    -- all three: after
    midcast_fallback = 40,   -- cleanup_midcast: before
    custom_states = 50,      -- all three: before (locks released) and after (the player's gear, locks laid again)
    cast_time = 60,          -- cleanup_precast: after
    combat_mode = 70,        -- handle_equipping_gear: before (lock) and after (holds)
}

local TARGETS = {'handle_equipping_gear', 'cleanup_precast', 'cleanup_midcast'}

local function registry()
    local layers = rawget(_G, '__action_hook_layers')
    if not layers then
        layers = {}
        for _, target in ipairs(TARGETS) do layers[target] = {} end
        _G.__action_hook_layers = layers
    end
    return layers
end

local reported = {}

local function failed(name, target, err)
    pcall(function()
        require('shared/utils/debug/trace_log').log('HOOKS', '%s on %s failed: %s', name, target, tostring(err))
    end)
    if reported[name] then return end
    reported[name] = true
    pcall(function()
        require('shared/utils/messages/message_formatter').show_error(
            '[' .. name .. '] failed on ' .. target .. ': ' .. tostring(err))
    end)
end

--- Register a layer (a second call with the same name replaces it).
--- @param name string One of ORDER's names
--- @param target string 'handle_equipping_gear', 'cleanup_precast' or 'cleanup_midcast'
--- @param layer table {before = fn(a, b, c), after = fn(token, a, b, c)}
function ActionHooks.add(name, target, layer)
    assert(ActionHooks.ORDER[name], 'ActionHooks: no place in ORDER for ' .. tostring(name))
    local layers = registry()[target]
    assert(layers, 'ActionHooks: not a hooked function: ' .. tostring(target))
    layer.name = name
    for i, existing in ipairs(layers) do
        if existing.name == name then
            layers[i] = layer
            return
        end
    end
    layers[#layers + 1] = layer
end

local function wrap(inner, layer, target)
    local name, before, after = layer.name, layer.before, layer.after
    return function(a, b, c)
        local token
        if before then
            local ok, result = pcall(before, a, b, c)
            if ok then token = result else failed(name, target, result) end
        end
        local result = inner(a, b, c)
        if after then
            local ok, err = pcall(after, token, a, b, c)
            if not ok then failed(name, target, err) end
        end
        return result
    end
end

--- Wrap each of Mote's three functions with its layers, in ORDER. Called once Mote has defined them
--- (INIT_SYSTEMS, after the systems have registered); a second call in the same load changes nothing.
function ActionHooks.install()
    local built = rawget(_G, '__action_hooks_built') or {}
    _G.__action_hooks_built = built
    for _, target in ipairs(TARGETS) do
        local inner = rawget(_G, target)
        local layers = registry()[target]
        if type(inner) == 'function' and built[target] ~= inner and #layers > 0 then
            table.sort(layers, function(x, y) return ActionHooks.ORDER[x.name] < ActionHooks.ORDER[y.name] end)
            local fn = inner
            for _, layer in ipairs(layers) do fn = wrap(fn, layer, target) end
            _G[target] = fn
            built[target] = fn
        end
    end
end

--- The layers of each function, innermost first (//gs c syscheck, the tests).
--- @return table target -> {names}
function ActionHooks.layers()
    local out = {}
    for _, target in ipairs(TARGETS) do
        local names = {}
        for _, layer in ipairs(registry()[target]) do names[#names + 1] = layer.name end
        table.sort(names, function(x, y) return ActionHooks.ORDER[x] < ActionHooks.ORDER[y] end)
        out[target] = names
    end
    return out
end

return ActionHooks
