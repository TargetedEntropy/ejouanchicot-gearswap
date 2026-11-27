---============================================================================
--- The offline Lua tests' shared helpers (scripts/atelier/*_test.lua)
---============================================================================
--- One copy of what every test used to write for itself: the checks and their
--- count, the end-of-run line and exit code, a time-ordered task queue for the
--- virtual clocks, module stubs, and a scratch folder that works on Windows
--- and Linux.
---
---   local T = dofile('scripts/lib/testlib.lua')    -- tests run from data/
---   local check = T.eq                             -- check(what, got, want)
---   T.ok('the hold is kept', held, 'held: ' .. tostring(held))
---   T.done()                                       -- "12 checks, 0 failed", exit 1 on a failure
---
--- T.verbose = true prints every check ("ok   <what>"), not only the failed ones.
---
--- @file    scripts/lib/testlib.lua
---============================================================================
local T = {checks = 0, failed = 0, verbose = false}

local function report(ok, what, why)
    T.checks = T.checks + 1
    if not ok then
        T.failed = T.failed + 1
        print('FAILED ' .. tostring(what) .. (why and (': ' .. why) or ''))
    elseif T.verbose then
        print('ok   ' .. tostring(what))
    end
    return ok
end

--- A value equal to the one wanted (==).
function T.eq(what, got, want)
    return report(got == want, what, ('got %s, wanted %s'):format(tostring(got), tostring(want)))
end

--- A condition that holds; detail, when given, is printed with a failure.
function T.ok(what, cond, detail)
    return report(cond and true or false, what, detail ~= nil and tostring(detail) or nil)
end

--- The end of a test: the count, then exit 1 when a check failed.
function T.done()
    print(('%d checks, %d failed'):format(T.checks, T.failed))
    os.exit(T.failed == 0 and 0 or 1)
end

--- Put a task {at = <time>, ...} into a queue kept in time order. Tasks due at the same time stay in the order they
--- were put in: table.sort is not stable in Lua 5.1, so a queue sorted on 'at' alone ran same-time tasks out of order.
--- The queue's first task is always the next one due: table.remove(queue, 1).
--- @return table the task
function T.push(queue, task)
    local i = #queue
    while i > 0 and queue[i].at > task.at do i = i - 1 end
    table.insert(queue, i + 1, task)
    return task
end

--- Make require(name) return tbl.
function T.module(name, tbl)
    package.loaded[name] = tbl
    return tbl
end

local WINDOWS = package.config:sub(1, 1) == '\\'

--- A fresh, empty scratch folder for this test (in the system's temp folder), with '/' separators and no final '/'.
function T.tmpdir(name)
    local base = (os.getenv('TEMP') or os.getenv('TMPDIR') or '/tmp'):gsub('\\', '/'):gsub('/$', '')
    local dir = base .. '/' .. name
    T.rmtree(dir)
    T.mkdir(dir)
    return dir
end

--- Make a folder and the folders above it.
function T.mkdir(path)
    if WINDOWS then
        os.execute('mkdir "' .. path:gsub('/', '\\') .. '" 2>nul')
    else
        os.execute("mkdir -p '" .. path .. "' 2>/dev/null")
    end
end

--- The names in a folder (files and folders, no '.' or '..'), as Windower's get_dir gives them.
function T.listdir(path)
    local out = {}
    local cmd = WINDOWS and ('dir /b "' .. path:gsub('/', '\\') .. '" 2>nul') or ("ls -A '" .. path .. "' 2>/dev/null")
    local p = io.popen(cmd)
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

--- Every file under a folder (recursive) whose name ends with ext, as paths starting with that folder, '/' separated.
function T.files(path, ext)
    local out = {}
    local cmd = WINDOWS and ('dir /s /b /a-d "' .. path:gsub('/', '\\') .. '" 2>nul') or ("find '" .. path .. "' -type f 2>/dev/null")
    local p = io.popen(cmd)
    for line in p:lines() do
        line = line:gsub('\\', '/')
        if WINDOWS then
            local at = line:lower():find('/' .. path:lower():gsub('%p', '%%%0') .. '/', 1)
            if at then line = line:sub(at + 1) end
        end
        if not ext or line:sub(-#ext) == ext then out[#out + 1] = line end
    end
    p:close()
    table.sort(out)
    return out
end

--- Copy a folder and everything in it into dst (made if missing).
function T.copytree(src, dst)
    T.mkdir(dst)
    if WINDOWS then
        os.execute('xcopy /e /i /q "' .. src:gsub('/', '\\') .. '" "' .. dst:gsub('/', '\\') .. '" >nul')
    else
        os.execute("cp -R '" .. src .. "/.' '" .. dst .. "' 2>/dev/null")
    end
end

--- Remove a folder and everything in it.
function T.rmtree(path)
    if WINDOWS then
        os.execute('rmdir /s /q "' .. path:gsub('/', '\\') .. '" 2>nul')
    else
        os.execute("rm -rf '" .. path .. "' 2>/dev/null")
    end
end

return T
