-- Drawing helper facade. Real drawing objects are only created by modules that need them.
local DrawingHelpers = {}

function DrawingHelpers.IsAvailable()
    return type(Drawing) == "table" and type(Drawing.new) == "function"
end

function DrawingHelpers.New(kind, properties)
    if not DrawingHelpers.IsAvailable() then
        return nil
    end
    local object = Drawing.new(kind)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    return object
end

return DrawingHelpers
