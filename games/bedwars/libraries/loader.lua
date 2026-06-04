-- BedWars module-group loader.
local BedWarsLoader = {}

BedWarsLoader.Groups = {
    "Combat",
    "Blatant",
    "Render",
    "Utility",
    "World",
    "Inventory",
    "Minigames",
    "Friends",
    "Targets",
    "Profiles",
    "Legit",
    "Kits",
    "BoostFPS"
}

local function notify(text)
    if type(shared) == "table" and type(shared.vape) == "table" and type(shared.vape.CreateNotification) == "function" then
        pcall(function()
            shared.vape:CreateNotification("AetherCore", text, 5)
        end)
    else
        warn("[AetherCore] " .. tostring(text))
    end
end

function BedWarsLoader.Load(context)
    if type(shared) ~= "table" or type(shared.vape) ~= "table" then
        return false, "compatibility GUI core is unavailable"
    end

    context.BedWars = context.BedWars or {
        Groups = {},
        LoadedAt = tick and tick() or os.time(),
        CompatibilityPayload = "games/bedwars/modules/compatibility_payload.luau"
    }

    local loadedGroups = 0
    for _, groupName in ipairs(BedWarsLoader.Groups) do
        local path = "games/bedwars/modules/" .. groupName .. ".lua"
        local ok, result = pcall(function()
            return context.RunFunctionModule(path)
        end)
        context.BedWars.Groups[groupName] = ok and (result ~= false) or false
        if ok and result ~= false then
            loadedGroups = loadedGroups + 1
        else
            warn("[AetherCore] BedWars " .. groupName .. " group failed: " .. tostring(result))
        end
    end

    local before = tonumber(context.State and context.State.ModuleRegistrationCount) or 0
    local payloadOk, payloadError = pcall(function()
        return context.RunFunctionModule(context.BedWars.CompatibilityPayload)
    end)
    if not payloadOk then
        return false, "compatibility payload failed: " .. tostring(payloadError)
    end

    local after = tonumber(context.State and context.State.ModuleRegistrationCount) or 0
    if after <= before and loadedGroups == 0 then
        notify("No BedWars modules registered. Check module routing and payload files.")
        return false, "zero BedWars modules registered"
    end

    notify("Loaded BedWars modules (" .. tostring(after - before) .. " compatibility registrations, " .. tostring(loadedGroups) .. " groups)")
    return true
end

return BedWarsLoader
