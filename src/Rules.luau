local Rules = {}
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Rules.plan(rows, options)
    assert(#rows > 0 and #rows <= 1000, "Choose between 1 and 1000 ProximityPrompts.")
    assert(finite(options.distance) and options.distance >= 0 and options.distance <= 100, "Distance must be between 0 and 100 studs.")
    assert(finite(options.hold) and options.hold >= 0 and options.hold <= 60, "Hold duration must be between 0 and 60 seconds.")
    assert(type(options.lineOfSight) == "boolean", "Line of sight must be on or off.")
    local plan = {}
    for _, row in ipairs(rows) do
        if row.distance ~= options.distance or row.hold ~= options.hold or row.lineOfSight ~= options.lineOfSight then
            table.insert(plan, { before = row, distance = options.distance, hold = options.hold, lineOfSight = options.lineOfSight })
        end
    end
    return plan
end

return Rules
