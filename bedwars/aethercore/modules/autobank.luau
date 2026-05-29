moduleSettings["AutoBank"] = {
    range = 18,
    keepIron = 64,
    delay = 0.3,
    requireChest = true
}

local function shouldDepositTool(tool, settings)
    local name = tool.Name:lower()
    if name:find("sword", 1, true) or name:find("pickaxe", 1, true) or name:find("axe", 1, true) or name:find("wool", 1, true) then
        return false
    end
    if name:find("iron", 1, true) and tonumber(settings.keepIron) and tonumber(settings.keepIron) > 0 then
        return false
    end
    return name:find("diamond", 1, true) or name:find("emerald", 1, true) or name:find("gold", 1, true) or name:find("iron", 1, true)
end

local function depositTool(tool, chest)
    local remote = getNearestRemoteByKeywords({"chest"}, {"RemoteEvent", "RemoteFunction"})
        or getNearestRemoteByKeywords({"bank"}, {"RemoteEvent", "RemoteFunction"})
        or getNearestRemoteByKeywords({"inventory"}, {"RemoteEvent", "RemoteFunction"})
    return invokeBedwarsRemote(remote, {
        chest = chest,
        chestId = chest and (chest:GetAttribute("ChestId") or chest:GetAttribute("chestId")),
        item = getToolItemType(tool),
        tool = tool,
        action = "deposit"
    })
end

function toggleAutoBank(enabled)
    cleanupModule("AutoBank")
    if not enabled then return end
    addConnection("AutoBank", task.spawn(function()
        while moduleStates["AutoBank"] do
            local settings = moduleSettings["AutoBank"] or {}
            local chest = getNearestTaggedOrNamedObject({"personal", "chest"}, math.clamp(tonumber(settings.range) or 18, 4, 40), nil)
                or getNearestTaggedOrNamedObject({"chest"}, math.clamp(tonumber(settings.range) or 18, 4, 40), nil)
            if chest or settings.requireChest == false then
                local backpack = lplr:FindFirstChildOfClass("Backpack")
                if backpack then
                    for _, tool in ipairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") and shouldDepositTool(tool, settings) then
                            depositTool(tool, chest)
                            task.wait(0.05)
                        end
                    end
                end
            end
            task.wait(math.max(0.1, tonumber(settings.delay) or 0.3))
        end
    end))
end

Aether.RegisterModule({
    Name = "AutoBank",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoBank"] or {},
    Start = function(ctx)
        toggleAutoBank(true)
    end,
    Stop = function(ctx)
        toggleAutoBank(false)
    end
})
