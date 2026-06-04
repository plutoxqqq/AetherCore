-- BedWars reference-only module registrations.
-- These names are present in the local reference payloads but were not present
-- in AetherCore's merged compatibility payload.  They are registered as safe
-- bridge modules so premade profiles can resolve every referenced module name
-- without forcing another full legacy payload into memory.
return function(context)
    local vape = shared and shared.vape
    if type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return false, "GUI categories are unavailable"
    end

    local categories = vape.Categories
    local function getCategory(name, fallback)
        local category = categories[name] or categories[fallback] or categories.Utility
        if type(category) == "table" and type(category.CreateModule) == "function" then
            return category
        end
        for _, candidate in pairs(categories) do
            if type(candidate) == "table" and type(candidate.CreateModule) == "function" then
                return candidate
            end
        end
        return nil
    end

    local definitions = {
        {Name = "Armor Highlight", Category = "Render", Reference = "catvape"},
        {Name = "Armor Trims", Category = "Render", Reference = "catvape"},
        {Name = "AntiDizzy", Category = "Utility", Reference = "lionv5"},
        {Name = "AutoEldertree", Category = "Utility", Reference = "lionv5", FormalName = "Auto Eldertree"},
        {Name = "Auto Lasso", Category = "Utility", Reference = "catvape"},
        {Name = "AutoRelease", Category = "Combat", Reference = "lionv5", FormalName = "Auto Release"},
        {Name = "Back Track", Category = "Combat", Reference = "catvape"},
        {Name = "Bed Assist", Category = "Combat", Reference = "catvape"},
        {Name = "Bed Protector", Category = "World", Reference = "catvape"},
        {Name = "Block Overlay", Category = "Render", Reference = "catvape"},
        {Name = "Clutch", Category = "World", Reference = "lionv5"},
        {Name = "Device Spoofer", Category = "Utility", Reference = "catvape"},
        {Name = "ElektraExtender", Category = "Utility", Reference = "lionv5", FormalName = "Elektra Extender"},
        {Name = "Fake Lag", Category = "Utility", Reference = "catvape"},
        {Name = "Fullbright", Category = "Render", Reference = "lionv5"},
        {Name = "KitRender (5v5)", Category = "Render", Reference = "lionv5", FormalName = "Kit Render (5v5)"},
        {Name = "KitRender (squads)", Category = "Render", Reference = "lionv5", FormalName = "Kit Render (Squads)"},
        {Name = "MartinSpeed", Category = "Blatant", Reference = "lionv5", FormalName = "Martin Speed"},
        {Name = "Owl Aura", Category = "Combat", Reference = "catvape"},
        {Name = "Player Attach", Category = "Utility", Reference = "catvape"},
        {Name = "Potion Status", Category = "Render", Reference = "catvape"},
        {Name = "ProjectileAimAssist", Category = "Combat", Reference = "lionv5", FormalName = "Projectile Aim Assist"},
        {Name = "Silent Aura", Category = "Combat", Reference = "catvape"},
        {Name = "SilentAura", Category = "Combat", Reference = "lionv5", FormalName = "Silent Aura"},
        {Name = "SilentAura(aero - testing)", Category = "Combat", Reference = "aerov4", FormalName = "Silent Aura (Aero Testing)"},
        {Name = "Skin Changer", Category = "Render", Reference = "catvape"},
        {Name = "Viewmodel Visuals", Category = "Render", Reference = "catvape"}
    }

    context.BedWars = context.BedWars or {Groups = {}}
    context.BedWars.Groups = context.BedWars.Groups or {}
    context.BedWars.Groups.ReferenceExtras = true
    context.BedWars.ReferenceExtras = context.BedWars.ReferenceExtras or {}

    local registered = 0
    for _, definition in ipairs(definitions) do
        local category = getCategory(definition.Category, "Utility")
        if not category then
            return false, "No compatible category exists for reference extras"
        end

        category:CreateModule({
            Name = definition.Name,
            Function = function(callback)
                if callback and type(vape.CreateNotification) == "function" then
                    vape:CreateNotification(
                        "AetherCore",
                        (definition.FormalName or definition.Name) .. " is available from the " .. definition.Reference .. " reference bridge.",
                        3
                    )
                end
            end,
            Tooltip = "Reference bridge for " .. (definition.FormalName or definition.Name) .. " from " .. definition.Reference .. "."
        })

        context.BedWars.ReferenceExtras[definition.Name] = definition.FormalName or definition.Name
        registered = registered + 1
    end

    return registered > 0
end
