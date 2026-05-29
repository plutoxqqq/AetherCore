moduleSettings["ArmorSwitch"] = {
    mode = "Best",
    range = 18,
    delay = 0.25
}

local armorRanks = {
    leather = 1,
    chain = 2,
    iron = 3,
    diamond = 4,
    emerald = 5,
    void = 6
}

local function getArmorRank(tool)
    local lowered = tool and tool.Name:lower() or ""
    local rank = 0
    for keyword, value in pairs(armorRanks) do
        if lowered:find(keyword, 1, true) then
            rank = math.max(rank, value)
        end
    end
    if lowered:find("helmet", 1, true) or lowered:find("chestplate", 1, true) or lowered:find("boots", 1, true) then
        return rank
    end
    return 0
end

local function equipBestArmor()
    local bestTool, bestRank = nil, 0
    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local rank = getArmorRank(tool)
                if rank > bestRank then
                    bestTool, bestRank = tool, rank
                end
            end
        end
    end
    if bestTool then
        equipToolIfNeeded(bestTool)
        safeCall("ArmorSwitchActivate", function()
            bestTool:Activate()
        end)
    end
end

function toggleArmorSwitch(enabled)
    cleanupModule("ArmorSwitch")
    if not enabled then return end
    addConnection("ArmorSwitch", task.spawn(function()
        while moduleStates["ArmorSwitch"] do
            local settings = moduleSettings["ArmorSwitch"] or {}
            local shouldEquip = tostring(settings.mode or "Best") == "Best"
            if not shouldEquip then
                local target = getNearestEnemy(math.clamp(tonumber(settings.range) or 18, 4, 40), true)
                shouldEquip = target ~= nil
            end
            if shouldEquip then
                equipBestArmor()
            end
            task.wait(math.max(0.1, tonumber(settings.delay) or 0.25))
        end
    end))
end

Aether.RegisterModule({
    Name = "ArmorSwitch",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["ArmorSwitch"] or {},
    Start = function(ctx)
        toggleArmorSwitch(true)
    end,
    Stop = function(ctx)
        toggleArmorSwitch(false)
    end
})
