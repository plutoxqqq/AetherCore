-- Wurst GUI compatibility alias.
-- A dedicated Wurst interface is not maintained by AetherCore yet, so this
-- applies a Wurst-inspired theme and delegates to the stable default GUI.
return function(context)
    local theme = context.Libraries.theme
    if theme then
        theme.Apply({
            Name = "wurst",
            Accent = Color3.fromRGB(255, 142, 40),
            Background = Color3.fromRGB(24, 20, 18),
            Text = Color3.fromRGB(255, 244, 230)
        })
    end
    return context.LoadModule("guis/new.lua")
end
