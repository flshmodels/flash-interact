local Rules = require(script.Parent.Rules)
local Scope = require(script.Parent.Scope)
local Adapter = {}

function Adapter.controls(panel, changed)
    panel.label("Set distance, hold duration and line-of-sight settings together. This changes prompt behavior, not server permissions or anti-cheat checks.")
    local distance = panel.field("Activation distance (studs, 0-100)", "10")
    local hold = panel.field("Hold duration (seconds, 0-60)", "0.5")
    local sight = panel.cycle("Requires line of sight", { "On", "Off" }, changed)
    local scope = panel.cycle("Scope", { "Selection only", "Include descendants" }, changed)
    distance:GetPropertyChangedSignal("Text"):Connect(changed)
    hold:GetPropertyChangedSignal("Text"):Connect(changed)
    return function() return { distance = tonumber(distance.Text), hold = tonumber(hold.Text), lineOfSight = sight() == "On", expand = scope() == "Include descendants" } end
end

function Adapter.plan(selection, options)
    local prompts, scanned = Scope.collect(selection, options.expand, function(object) return object:IsA("ProximityPrompt") end)
    local rows = {}
    for _, prompt in ipairs(prompts) do
        table.insert(rows, { target = prompt, parent = prompt.Parent, distance = prompt.MaxActivationDistance, hold = prompt.HoldDuration, lineOfSight = prompt.RequiresLineOfSight })
    end
    local plan = Rules.plan(rows, options)
    plan.summary = string.format("%d changes / %d prompts / %d objects scanned.", #plan, #prompts, scanned)
    for _, entry in ipairs(plan) do
        local before = entry.before
        entry.label = string.format("%s\nDistance %g -> %g; hold %g -> %g; line of sight %s -> %s", before.target:GetFullName(), before.distance, entry.distance, before.hold, entry.hold, tostring(before.lineOfSight), tostring(entry.lineOfSight))
    end
    return plan
end

function Adapter.validate(plan)
    for _, entry in ipairs(plan) do
        local before = entry.before
        local target = before.target
        if not target:IsDescendantOf(game) or target.Parent ~= before.parent
            or target.MaxActivationDistance ~= before.distance or target.HoldDuration ~= before.hold or target.RequiresLineOfSight ~= before.lineOfSight then
            return false, "A prompt or one of the three settings changed. Preview again."
        end
    end
    return true
end

function Adapter.write(entry)
    local prompt = entry.before.target
    prompt.MaxActivationDistance = entry.distance
    prompt.HoldDuration = entry.hold
    prompt.RequiresLineOfSight = entry.lineOfSight
end

return Adapter
