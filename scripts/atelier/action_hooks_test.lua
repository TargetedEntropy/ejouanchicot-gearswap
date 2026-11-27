---============================================================================
--- Test of the gear chain (shared/utils/core/action_hooks.lua and the layers that register on it)
--- Run from data/: lua5.1 scripts/atelier/action_hooks_test.lua
---============================================================================
--- The real install functions run in INIT_SYSTEMS order on Mote's three functions, each layer's work replaced by
--- a note, then ActionHooks.install():
---   1. the order of maintainer-guide.md section 3, whatever order the layers registered in
---   2. one wrap per load: a second install() changes nothing
---   3. a layer that fails is named, and the others and Mote's own function still run
--- @file scripts/atelier/action_hooks_test.lua
---============================================================================
package.path = './?.lua;' .. package.path
local T = dofile('scripts/lib/testlib.lua')
local check = T.eq

local log = {}
local function note(s) log[#log + 1] = s end

windower = {raw_register_event = function() return 1 end, register_event = function() return 1 end,
    ffxi = {get_player = function() return {buffs = {}} end, get_items = function() return {} end,
            get_mob_by_target = function() return nil end}}
player = {status = 'Engaged', name = 'X'}
sets = {TreasureHunter = {waist = 'TH belt'}}
equip = function(s) note(s == sets.TreasureHunter and 'TH' or 'equip') end
midaction = function() return false end
handle_equipping_gear = function() note('Mote status set') end
cleanup_precast = function() note('Mote cleanup_precast') end
cleanup_midcast = function() note('Mote cleanup_midcast') end
local errors = {}
T.module('shared/utils/messages/message_formatter', {show_error = function(m) errors[#errors + 1] = m end})
T.module('shared/utils/debug/trace_log', {log = function() end})
T.module('shared/utils/custom/custom_states_validate', {})
T.module('shared/utils/custom/custom_conditions', {})
T.module('shared/utils/custom/custom_guards', {hands_off = function() note('Custom equip') return true end})
T.module('shared/utils/custom/custom_locks', {collect = function() end,
    release = function() note('Custom release locks') end, apply = function() note('Custom re-lock') end})
T.module('shared/utils/core/optional_state', {create = function() return {} end})
T.module('shared/utils/core/gear_hold', {active = function() return false end})

local EB = require('shared/utils/equipment/elemental_belt'); EB.apply = function(_, p) note('Belt ' .. p) end
local DW = require('shared/utils/equipment/dual_wield'); DW.apply = function() note('DualWield') end
local TH = require('shared/utils/equipment/treasure_hunter')
TH.init = function() end
TH.lay_engaged = function() note('TH') end
TH.optional = {value = function() return 'Full' end}
TH.wants_engaged_th = function() return true end
local MF = require('shared/utils/midcast/midcast_fallback'); MF.route = function() note('MidcastFallback route') end
local CS = require('shared/utils/custom/custom_states'); _G._custom_state_entries = {{}}
local CT = require('shared/utils/precast/cast_time'); CT.estimate = function() note('CastTime estimate') return 1, 0 end
local CM = require('shared/utils/core/combat_mode'); CM.apply = function() note('CombatMode lock') end
local AH = require('shared/utils/core/action_hooks')

-- registered out of order on purpose: the chain follows ActionHooks.ORDER
CM.install_hook(); CT.install_hook(); EB.install(); CS.install_hooks(); DW.install(); MF.install(); TH.install()
AH.install()

local spell = {english = 'Fire', action_type = 'Magic', target = {type = 'MONSTER', id = 42}}
local function run(fn, ...)
    log = {}
    fn(...)
    return table.concat(log, ' -> ')
end

-- 1. the order (maintainer-guide.md section 3)
check('handle_equipping_gear', run(handle_equipping_gear, 'Engaged'),
    'CombatMode lock -> Custom release locks -> Mote status set -> DualWield -> TH -> Custom equip -> Custom re-lock')
check('cleanup_precast', run(cleanup_precast, spell, nil, {cancel = false}),
    'Belt precast -> Mote cleanup_precast -> Custom equip -> CastTime estimate')
check('cleanup_midcast', run(cleanup_midcast, spell, nil, {cancel = false}),
    'MidcastFallback route -> Belt midcast -> Mote cleanup_midcast -> TH -> Custom equip')
check('the layers listed innermost first', table.concat(AH.layers().handle_equipping_gear, ' '),
    'dual_wield treasure_hunter custom_states combat_mode')

-- 2. one wrap per load
local before = handle_equipping_gear
AH.install()
check('a second install changes nothing', handle_equipping_gear, before)
check('  and the chain runs once', run(handle_equipping_gear, 'Engaged'),
    'CombatMode lock -> Custom release locks -> Mote status set -> DualWield -> TH -> Custom equip -> Custom re-lock')

-- 3. a layer that fails stops nothing else (it used to abort every layer outside it)
DW.apply = function() error('boom') end
check('a failing layer: the others still run', run(handle_equipping_gear, 'Engaged'),
    'CombatMode lock -> Custom release locks -> Mote status set -> TH -> Custom equip -> Custom re-lock')
check('  named in chat', errors[1] and errors[1]:find('[dual_wield]', 1, true) ~= nil, true)
run(handle_equipping_gear, 'Engaged')
check('  once per load', #errors, 1)

T.done()
