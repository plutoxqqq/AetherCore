-- Theme values shared by GUI implementations.
local Theme = {
    Name = "new",
    Accent = Color3.fromRGB(130, 95, 255),
    Background = Color3.fromRGB(20, 20, 28),
    Text = Color3.fromRGB(245, 245, 255)
}

function Theme.Apply(values)
    for key, value in pairs(values or {}) do
        Theme[key] = value
    end
    return Theme
end

return Theme
