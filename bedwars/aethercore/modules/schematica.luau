moduleSettings["Schematica"] = {
    fileName = "AetherCoreSchematica.json",
    mode = "Build",
    range = 24,
    delay = 0.08,
    transparency = 0.45
}

local function readSchematic()
    if type(readfile) ~= "function" or type(HttpService.JSONDecode) ~= "function" then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile((moduleSettings["Schematica"] or {}).fileName or "AetherCoreSchematica.json"))
    end)
    return ok and type(data) == "table" and data or nil
end

local function saveSchematic(blocks)
    if type(writefile) ~= "function" then return false end
    return safeCall("SchematicaSave", function()
        writefile((moduleSettings["Schematica"] or {}).fileName or "AetherCoreSchematica.json", HttpService:JSONEncode(blocks))
        return true
    end) or false
end

local function collectNearbyBlocks()
    local char = getCharacter(lplr)
    local root = getHRP(char)
    if not root then return {} end
    local blocks = {}
    local range = math.clamp(tonumber((moduleSettings["Schematica"] or {}).range) or 24, 4, 80)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(char) and (obj.Position - root.Position).Magnitude <= range then
            table.insert(blocks, {
                name = obj.Name,
                x = math.floor((obj.Position.X - root.Position.X) / 3 + 0.5),
                y = math.floor((obj.Position.Y - root.Position.Y) / 3 + 0.5),
                z = math.floor((obj.Position.Z - root.Position.Z) / 3 + 0.5)
            })
        end
    end
    return blocks
end

local function placeSchematicBlock(origin, block)
    local tool = getHeldOrBackpackBlockTool()
    if not tool or not equipToolIfNeeded(tool) then return false end
    local position = Vector3.new(origin.X + ((block.x or 0) * 3), origin.Y + ((block.y or 0) * 3), origin.Z + ((block.z or 0) * 3))
    local remote = getNearestRemoteByKeywords({"place", "block"}, {"RemoteEvent", "RemoteFunction"})
    return invokeBedwarsRemote(remote, {position = position, blockPosition = position, item = getToolItemType(tool)})
end

local function toggleSchematica(enabled)
    cleanupModule("Schematica")
    if not enabled then return end
    if tostring((moduleSettings["Schematica"] or {}).mode or "Build") == "Save" then
        saveSchematic(collectNearbyBlocks())
        setModuleEnabled("Schematica", false)
        return
    end
    local schematic = readSchematic()
    if not schematic then
        warn("[AetherCore] Schematica file is missing or invalid.")
        setModuleEnabled("Schematica", false)
        return
    end
    local origin = getHRP(getCharacter(lplr)) and getHRP(getCharacter(lplr)).Position or Vector3.zero
    addConnection("Schematica", task.spawn(function()
        for _, block in ipairs(schematic) do
            if not moduleStates["Schematica"] then return end
            placeSchematicBlock(origin, block)
            task.wait(math.max(0.03, tonumber((moduleSettings["Schematica"] or {}).delay) or 0.08))
        end
        setModuleEnabled("Schematica", false)
    end))
end

Aether.RegisterModule({
    Name = "Schematica",
    Category = "World",
    Default = false,
    Settings = moduleSettings["Schematica"] or {},
    Start = function(ctx)
        toggleSchematica(true)
    end,
    Stop = function(ctx)
        toggleSchematica(false)
    end
})
