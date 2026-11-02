local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Rules = require("../src/Rules")
local Transaction = require("../src/Transaction")
local count = 0
local function test(name, callback)
    local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err))
    count += 1
    print("PASS " .. name)
end
local function rejects(callback)
    assert(not pcall(callback), "expected an error")
end
for _, name in ipairs(fs.readDir("src")) do
    if name:match("%.luau$") then luau.compile(fs.readFile("src/" .. name)) end
end

test("transaction commits one batch", function()
    local writes, commits = 0, 0
    local ok = Transaction.apply({ {}, {} }, {
        validate = function() return true end,
        write = function() writes += 1 end,
    }, {
        begin = function() return "recording" end,
        finish = function(id, commit) assert(id == "recording" and commit) commits += 1 end,
    })
    assert(ok and writes == 2 and commits == 1)
end)
test("empty, stale and uncheckable plans never begin a recording", function()
    local function forbidden() error("must not be called") end
    for _, mode in ipairs({ "empty", "stale", "throw" }) do
        local began = false
        local ok = Transaction.apply(if mode == "empty" then {} else { {} }, {
            validate = function() if mode == "throw" then error("deleted") end return false, "stale" end,
            write = forbidden,
        }, { begin = function() began = true return "id" end, finish = forbidden })
        assert(not ok and not began)
    end
end)
test("refused or failing undo recordings do not edit objects", function()
    for _, mode in ipairs({ "refuse", "throw" }) do
        local writes = 0
        local ok = Transaction.apply({ {} }, { validate = function() return true end, write = function() writes += 1 end }, {
            begin = function() if mode == "throw" then error("busy") end return nil end,
            finish = function() error("must not finish") end,
        })
        assert(not ok and writes == 0)
    end
end)
test("write failures cancel and restore the fake scene", function()
    local state, snapshot, cancelled = 0, 0, false
    local ok = Transaction.apply({ {}, {} }, {
        validate = function() return true end,
        write = function() state += 1 if state == 2 then error("locked") end end,
    }, {
        begin = function() snapshot = state return "id" end,
        finish = function(_, commit) assert(not commit) state = snapshot cancelled = true end,
    })
    assert(not ok and cancelled and state == 0)
end)
test("failed commits attempt cancellation", function()
    local cancelled = false
    local ok = Transaction.apply({ {} }, { validate = function() return true end, write = function() end }, {
        begin = function() return "id" end,
        finish = function(_, commit) if commit then error("commit failed") end cancelled = true end,
    })
    assert(not ok and cancelled)
end)
test("failed cancellation is reported", function()
    local ok, message = Transaction.apply({ {} }, { validate = function() return true end, write = function() error("write failed") end }, {
        begin = function() return "id" end,
        finish = function() error("cancel failed") end,
    })
    assert(not ok and message:find("could not cancel", 1, true))
end)



local gameRoot = { Name = "Game", children = {} }
function gameRoot:IsA(class) return class == "DataModel" end
local services = {}
function gameRoot:FindService(class) return services[class] end
function gameRoot:GetService(class) return assert(services[class], "Service unavailable") end
local function object(name, parent, class)
    local node = { Name = name, Parent = parent, ClassName = class or "Folder", children = {}, MaxActivationDistance = 10, HoldDuration = 0, RequiresLineOfSight = true, ActionText = "Use", ObjectText = "Door", Enabled = true }
    function node:IsA(candidate) return candidate == self.ClassName end
    function node:IsDescendantOf(ancestor)
        local cursor = self.Parent
        while cursor do if cursor == ancestor then return true end cursor = cursor.Parent end
        return false
    end
    function node:GetChildren() return self.children end
    function node:GetFullName()
        local names, cursor = {}, self
        while cursor and cursor ~= gameRoot do table.insert(names, 1, cursor.Name) cursor = cursor.Parent end
        return table.concat(names, ".")
    end
    function node:WaitForChild(name, timeout)
        assert(timeout == 10)
        for _, child in ipairs(self.children) do if child.Name == name then return child end end
        return nil
    end
    if parent then table.insert(parent.children, node) end
    return node
end
local world = object("Workspace", gameRoot, "Workspace")
services.Workspace = world
local modules = { Rules = Rules }
if fs.isFile("src/Scope.luau") then
    modules.Scope = luau.load(fs.readFile("src/Scope.luau"), { environment = { game = gameRoot } })()
end
local Scope = modules.Scope
local Adapter = luau.load(fs.readFile("src/Adapter.luau"), { environment = {
    require = function(name) return assert(modules[name]) end,
    script = { Parent = { Rules = "Rules", Scope = "Scope" } }, game = gameRoot,
} })()
test("scope deduplicates overlapping roots", function()
    local folder = object("Folder", world)
    local a, b = object("A", folder), object("B", folder)
    local targets, scanned = Scope.collect({ folder, a }, true, function() return true end)
    assert(#targets == 3 and scanned == 3 and targets[1] == folder and targets[2] == b and targets[3] == a)
    local only = Scope.collect({ folder }, false, function() return true end)
    assert(#only == 1)
end)
test("scope rejects detached roots, services and empty selections", function()
    rejects(function() Scope.collect({}, true, function() return true end) end)
    rejects(function() Scope.collect({ world }, true, function() return true end) end)
    rejects(function() Scope.collect({ object("Detached", nil) }, true, function() return true end) end)
end)
test("scope limits discovered objects before returning partial results", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return false end, { maxNodes = 2, maxTargets = 2 }) end)
end)
test("scope target limit is independent of scan limit", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return true end, { maxNodes = 10, maxTargets = 2 }) end)
end)


test("preview preserves prompt text and enabled state", function()
    local prompt = object("Prompt", world, "ProximityPrompt")
    local plan = Adapter.plan({ prompt }, { distance = 12, hold = 0.5, lineOfSight = false })
    assert(#plan == 1 and prompt.MaxActivationDistance == 10 and Adapter.validate(plan))
    Adapter.write(plan[1])
    assert(prompt.MaxActivationDistance == 12 and prompt.HoldDuration == 0.5 and prompt.RequiresLineOfSight == false)
    assert(prompt.ActionText == "Use" and prompt.ObjectText == "Door" and prompt.Enabled == true)
end)
test("no-op prompt settings are omitted", function()
    local prompt = object("Prompt", world, "ProximityPrompt")
    assert(#Adapter.plan({ prompt }, { distance = 10, hold = 0, lineOfSight = true }) == 0)
end)
test("invalid and nonfinite prompt settings are refused", function()
    local prompt = object("Prompt", world, "ProximityPrompt")
    for _, distance in ipairs({ -1, 101, math.huge, 0/0 }) do
        rejects(function() Adapter.plan({ prompt }, { distance = distance, hold = 0, lineOfSight = true }) end)
    end
    for _, hold in ipairs({ -1, 61, math.huge }) do
        rejects(function() Adapter.plan({ prompt }, { distance = 10, hold = hold, lineOfSight = true }) end)
    end
end)
test("changed settings and removed targets invalidate prompt previews", function()
    local prompt = object("Prompt", world, "ProximityPrompt")
    local plan = Adapter.plan({ prompt }, { distance = 15, hold = 1, lineOfSight = true })
    prompt.HoldDuration = 2 assert(not Adapter.validate(plan))
    prompt.HoldDuration = 0 prompt.RequiresLineOfSight = false assert(not Adapter.validate(plan))
    prompt.RequiresLineOfSight = true prompt.Parent = nil assert(not Adapter.validate(plan))
end)
test("expanded prompt selections deduplicate roots", function()
    local folder = object("Folder", world)
    local prompt = object("Prompt", folder, "ProximityPrompt")
    object("Unrelated", folder, "Part")
    assert(#Adapter.plan({ folder, prompt }, { distance = 8, hold = 1, lineOfSight = true, expand = true }) == 1)
end)
test("false line-of-sight values are valid inputs", function()
    local prompt = object("Prompt", world, "ProximityPrompt") prompt.RequiresLineOfSight = false
    assert(#Adapter.plan({ prompt }, { distance = 10, hold = 0, lineOfSight = false }) == 0)
end)

print(string.format("%d checks passed", count))
