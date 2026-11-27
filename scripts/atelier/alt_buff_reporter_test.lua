---============================================================================
--- Test of the alt's buff reports to its main (shared/utils/dualbox/alt_buff_reporter.lua)
--- Run from data/: lua5.1 scripts/atelier/alt_buff_reporter_test.lua
---============================================================================
--- The report goes to the partner, read as dualbox_manager's get_target_character reads it: main_character, then
--- the legacy alt_name. main_name is this character's own name (an alias of character_name): an alt config that had
--- only it used to send its buffs to itself.
--- @file scripts/atelier/alt_buff_reporter_test.lua
---============================================================================
package.path = './?.lua;' .. package.path
local T = dofile('scripts/lib/testlib.lua')
local check = T.eq

local sent = {}
windower = {addon_path = './'}
send_command = function(cmd) sent[#sent + 1] = cmd end
player = {name = 'Kaories'}
T.module('shared/utils/core/char_paths', {log = function() return T.tmpdir('alt_buff_reporter_test') .. '/altbuff.log' end})
local R = dofile('shared/utils/dualbox/alt_buff_reporter.lua')

local function report(cfg)
    sent = {}
    _G.DualBoxConfig = cfg
    local ok = R.report('Entrust', true)
    return ok, sent[1]
end

local ok, cmd = report({enabled = true, role = 'alt', character_name = 'Kaories', main_character = 'Tetsouo'})
check('main_character: sent', ok, true)
check('  to the main', cmd, 'send Tetsouo gs c altbuff Entrust 1')

ok, cmd = report({enabled = true, role = 'alt', character_name = 'Kaories', alt_name = 'Tetsouo'})
check('legacy alt_name (the partner, as dualbox_role writes it): to the main', cmd, 'send Tetsouo gs c altbuff Entrust 1')

ok, cmd = report({enabled = true, role = 'alt', main_name = 'Kaories'})
check('only main_name (this character): nothing sent', ok, false)
check('  not to itself', cmd, nil)

ok, cmd = report({enabled = true, role = 'main', alt_character = 'Kaories'})
check('role main: nothing sent', ok, false)

ok = R.report('Haste', true)
check('an untracked buff: nothing sent', ok, false)

T.done()
