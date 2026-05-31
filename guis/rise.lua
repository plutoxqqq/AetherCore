-- Alternate GUI compatibility alias.
-- A dedicated Rise GUI is not present yet; this keeps the selector working without losing modules.
return function(context)
    local theme = context.Libraries.theme
    if theme then
        theme.Apply({Name = "rise", Accent = Color3.fromRGB(255, 80, 120)})
    end
    return context.LoadModule("guis/new.lua")
end
