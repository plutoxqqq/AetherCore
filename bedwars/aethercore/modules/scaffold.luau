moduleSettings["Scaffold"] = {
    allowTowering = true,
    placeAhead = 1
}

function getTeamWoolName()
    local team = lplr.Team
    if not team then return "wool_white" end
    local teamName = team.Name:lower()
    if teamName:find("blue") then return "wool_blue"
    elseif teamName:find("red") then return "wool_red"
    elseif teamName:find("green") then return "wool_green"
    elseif teamName:find("yellow") then return "wool_yellow"
    elseif teamName:find("aqua") then return "wool_cyan"
    elseif teamName:find("pink") then return "wool_pink"
    elseif teamName:find("gray") then return "wool_gray"
    elseif teamName:find("white") then return "wool_white"
    else return "wool_white" end
end

function toggleScaffold(enabled)
    cleanupModule("Scaffold")
    if not enabled then return end

    local function snapToBlockGrid(position)
        local blockSize = 3
        local function snap(value)
            return math.floor((value / blockSize) + 0.5) * blockSize
        end
        return Vector3.new(snap(position.X), snap(position.Y), snap(position.Z))
    end

    local function placeWithController(blockController, blockTool, woolName, placePosition)
        local didPlace = false
        local payloads = {
            CFrame.new(placePosition),
            placePosition,
            {blockPosition = placePosition},
            {position = placePosition},
            {blockType = blockTool.Name or woolName, position = placePosition}
        }
        for _, fnName in ipairs({"placeBlock", "PlaceBlock", "placeBlockAt", "placeBlockRequest"}) do
            local fn = blockController[fnName]
            if type(fn) == "function" then
                for _, payload in ipairs(payloads) do
                    local ok = safeCall("Scaffold_" .. fnName, function()
                        fn(blockController, payload)
                        return true
                    end)
                    didPlace = didPlace or (ok == true)
                    if didPlace then
                        return true
                    end
                end
            end
        end
        return didPlace
    end

    local function placeWithRemotes(blockTool, woolName, placePosition)
        local netManaged = getNetManagedFolder()
        if netManaged then
            for _, remoteName in ipairs({"PlaceBlock", "placeBlock", "ClientPlaceBlock"}) do
                local remote = netManaged:FindFirstChild(remoteName)
                if remote and remote:IsA("RemoteEvent") then
                    local didFire = safeCall("ScaffoldNetManaged_" .. remoteName, function()
                        remote:FireServer({
                            blockType = blockTool.Name or woolName,
                            blockPosition = placePosition,
                            position = placePosition
                        })
                        return true
                    end)
                    if didFire then
                        return true
                    end
                end
            end
        end

        local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
        if remotes then
            for _, remote in ipairs(remotes:GetDescendants()) do
                if remote:IsA("RemoteEvent") and remote.Name:lower():find("place") and remote.Name:lower():find("block") then
                    local didFire = safeCall("ScaffoldRemote_" .. remote.Name, function()
                        remote:FireServer({
                            position = placePosition,
                            blockPosition = placePosition,
                            blockType = blockTool.Name or woolName
                        })
                        return true
                    end)
                    if didFire then
                        return true
                    end
                end
            end
        end
        return false
    end

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["Scaffold"] then return end
        local myChar = getCharacter(lplr)
        local hum = getHumanoid(myChar)
        local hrp = getHRP(myChar)
        if not hrp or not hum then return end

        local woolName = getTeamWoolName()
        local blockTool = getHeldOrBackpackBlockTool()
        if not blockTool then
            return
        end
        if blockTool.Parent ~= myChar then
            equipToolIfNeeded(blockTool)
        end

        local downParams = RaycastParams.new()
        downParams.FilterType = Enum.RaycastFilterType.Exclude
        downParams.FilterDescendantsInstances = {myChar}
        downParams.IgnoreWater = true
        local downRay = Workspace:Raycast(hrp.Position, Vector3.new(0, -4.8, 0), downParams)
        if downRay and (hrp.Position.Y - downRay.Position.Y) <= 3.2 then
            return
        end

        local lookPlanar = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        if lookPlanar.Magnitude > 0 then
            lookPlanar = lookPlanar.Unit
        else
            lookPlanar = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
        end
        local placeAhead = math.clamp(moduleSettings["Scaffold"].placeAhead or 1, 0, 2)
        local basePos = hrp.Position + (lookPlanar * (placeAhead * 1.5)) - Vector3.new(0, 3, 0)
        local placePos = snapToBlockGrid(basePos)


        if moduleSettings["Scaffold"].allowTowering then
            if hum and hum:GetState() == Enum.HumanoidStateType.Jumping then
                placePos = snapToBlockGrid(hrp.Position - Vector3.new(0, 0.8, 0))
            end
        end


        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {myChar}
        local parts = Workspace:GetPartBoundsInBox(CFrame.new(placePos), Vector3.new(2, 2, 2), overlapParams)
        local blockExists = false
        for _, part in ipairs(parts) do
            if part:IsA("BasePart") and not part.Parent:IsA("Model") then
                blockExists = true
                break
            end
        end
        if blockExists then return end

        local blockController = getBlockPlacementController()
        if blockController and placeWithController(blockController, blockTool, woolName, placePos) then
            performPrimaryClick()
            return
        end

        if placeWithRemotes(blockTool, woolName, placePos) then
            performPrimaryClick()
            return
        end

        if BedwarsShopController then
            safeCall("ScaffoldShopFallback", function()
                local shopController = require(BedwarsShopController)
                local blockItem = shopController.GetItem and shopController:GetItem(woolName)
                if blockItem and shopController.PlaceBlock then
                    shopController:PlaceBlock(blockItem, CFrame.new(placePos))
                    performPrimaryClick()
                end
            end)
        end
    end)
    addConnection("Scaffold", connection)
end

Aether.RegisterModule({
    Name = "Scaffold",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["Scaffold"] or {},
    Start = function(ctx)
        toggleScaffold(true)
    end,
    Stop = function(ctx)
        toggleScaffold(false)
    end
})
