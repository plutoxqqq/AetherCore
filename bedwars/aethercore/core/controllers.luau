--====================================================
-- controller and remote resolvers
--====================================================

KnitClient, CombatController, BedwarsShopController, BlockPlacementController, ClientHandler = nil, nil, nil, nil, nil
resolvedCombatController, resolvedBlockPlacementController = nil, nil
cachedNetManagedFolder = nil
cachedDropItemRemote = nil
cachedDamageBlockRemote = nil

function fetchControllers()
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    local rbxtsInclude = ReplicatedStorage:FindFirstChild("rbxts_include")
    local nodeModules = rbxtsInclude and rbxtsInclude:FindFirstChild("node_modules")
    local rbxts = nodeModules and nodeModules:FindFirstChild("@rbxts")
    local net = rbxts and rbxts:FindFirstChild("net")
    local netOut = net and net:FindFirstChild("out")

    local knitPaths = {
        packages and packages:FindFirstChild("Knit"),
        netOut
    }
    for _, knit in ipairs(knitPaths) do
        if knit then
            KnitClient = knit:FindFirstChild("Client")
            if KnitClient then break end
        end
    end
    if not KnitClient then return end
    local controllers = KnitClient:FindFirstChild("Controllers")
    if controllers then
        CombatController = controllers:FindFirstChild("CombatController")
        BedwarsShopController = controllers:FindFirstChild("BedwarsShopController")
        BlockPlacementController = controllers:FindFirstChild("BlockPlacementController") or controllers:FindFirstChild("BlockController")
        ClientHandler = controllers:FindFirstChild("ClientHandler")
    end
end
fetchControllers()

vapeFunctionTable = {}
function refreshVapeFunctionTable()
    if type(getgc) ~= "function" then
        warnMissingOnce("getgc", "[AetherCore] getgc is not available; advanced controller discovery is limited.")
        return
    end

    for _, value in ipairs(getgc(true)) do
        if type(value) == "table" then
            if rawget(value, "ClientStore") and not vapeFunctionTable.ClientStore then
                vapeFunctionTable.ClientStore = value.ClientStore
            end
            if rawget(value, "BlockEngine") and type(value.BlockEngine) == "table" and not vapeFunctionTable.BlockEngine then
                vapeFunctionTable.BlockEngine = value.BlockEngine
            end
            if rawget(value, "ClientBlockEngine") and not vapeFunctionTable.ClientBlockEngine then
                vapeFunctionTable.ClientBlockEngine = value.ClientBlockEngine
            end
            if rawget(value, "getInventory") and not vapeFunctionTable.getInventory then
                vapeFunctionTable.getInventory = value.getInventory
            end
            if rawget(value, "attackEntity") and not vapeFunctionTable.attackEntity then
                vapeFunctionTable.attackEntity = value.attackEntity
            end
        end
    end
end
pcall(refreshVapeFunctionTable)

function getNetManagedFolder()
    if cachedNetManagedFolder and cachedNetManagedFolder.Parent then
        return cachedNetManagedFolder
    end
    local rbxtsInclude = ReplicatedStorage:FindFirstChild("rbxts_include")
    if not rbxtsInclude then return nil end
    local nodeModules = rbxtsInclude:FindFirstChild("node_modules")
    if not nodeModules then return nil end
    local rbxtsNet = nodeModules:FindFirstChild("@rbxts")
    rbxtsNet = rbxtsNet and rbxtsNet:FindFirstChild("net")
    rbxtsNet = rbxtsNet and rbxtsNet:FindFirstChild("out")
    local netManaged = rbxtsNet and rbxtsNet:FindFirstChild("_NetManaged")
    cachedNetManagedFolder = netManaged
    return cachedNetManagedFolder
end

function getDropItemRemote()
    if cachedDropItemRemote and cachedDropItemRemote.Parent then
        return cachedDropItemRemote
    end
    local netManaged = getNetManagedFolder()
    cachedDropItemRemote = netManaged and netManaged:FindFirstChild("DropItem")
    return cachedDropItemRemote
end

function getDamageBlockRemote()
    if cachedDamageBlockRemote and cachedDamageBlockRemote.Parent then
        return cachedDamageBlockRemote
    end
    local netManaged = getNetManagedFolder()
    cachedDamageBlockRemote = netManaged and netManaged:FindFirstChild("DamageBlock")
    return cachedDamageBlockRemote
end



--====================================================
-- character helpers
--====================================================

function getCharacter(player)
    return player and player.Character
end

function isPlayerCharacterModel(model)
    if not model or not model:IsA("Model") then
        return false
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == model then
            return true
        end
    end
    return false
end

function getHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

function getHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

function getHumanoidScale(humanoid, scaleName, defaultValue)
    local fallback = defaultValue or 1
    if not humanoid then
        return fallback
    end
    local scale = humanoid:FindFirstChild(scaleName)
    if scale and scale:IsA("NumberValue") then
        return scale.Value
    end
    return fallback
end

function getCharacterAndHumanoid(player)
    local character = player and (player.Character or player.CharacterAdded:Wait())
    if not character then
        return nil, nil
    end
    return character, character:FindFirstChildOfClass("Humanoid")
end


--====================================================
-- movement/raycast helpers
--====================================================

function raycastToGround(origin, ignoreList, castDistance)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList or {}
    return Workspace:Raycast(origin, Vector3.new(0, -(castDistance or 400), 0), params)
end

function findNearestGroundPosition(origin, character, sampleRadius, sampleStep, verticalOffset)
    local bestPosition = nil
    local closestPlanar = math.huge
    local radius = sampleRadius or 14
    local step = sampleStep or 7
    local originPlanar = Vector3.new(origin.X, 0, origin.Z)

    for x = -radius, radius, step do
        for z = -radius, radius, step do
            local sampleOrigin = origin + Vector3.new(x, 35, z)
            local hit = raycastToGround(sampleOrigin, {character}, 420)
            if hit then
                local planar = Vector3.new(hit.Position.X, 0, hit.Position.Z)
                local planarDistance = (planar - originPlanar).Magnitude
                if planarDistance < closestPlanar then
                    closestPlanar = planarDistance
                    bestPosition = hit.Position + Vector3.new(0, verticalOffset or 3, 0)
                end
            end
        end
    end

    return bestPosition
end

function getCombatController()
    if resolvedCombatController then
        return resolvedCombatController
    end
    if not CombatController then return nil end
    local ok, controller = pcall(require, CombatController)
    if ok and controller then
        resolvedCombatController = controller
    end
    return resolvedCombatController
end

function getBlockPlacementController()
    if resolvedBlockPlacementController then
        return resolvedBlockPlacementController
    end
    if not BlockPlacementController then return nil end
    local ok, controller = pcall(require, BlockPlacementController)
    if ok and controller then
        resolvedBlockPlacementController = controller
    end
    return resolvedBlockPlacementController
end


--====================================================
-- item and tool helpers
--====================================================

function doesToolNameMatch(tool, query)
    if not tool or not tool:IsA("Tool") or type(query) ~= "string" then
        return false
    end
    local normalizedToolName = tool.Name:lower()
    local normalizedQuery = query:lower()
    return normalizedToolName == normalizedQuery or normalizedToolName:find(normalizedQuery, 1, true) ~= nil
end

function findToolInContainer(container, query)
    if not container then
        return nil
    end

    local exactMatch = container:FindFirstChild(query)
    if exactMatch and exactMatch:IsA("Tool") then
        return exactMatch
    end

    for _, descendant in ipairs(container:GetChildren()) do
        if descendant:IsA("Tool") and doesToolNameMatch(descendant, query) then
            return descendant
        end
    end

    return nil
end

function hasItem(itemName)
    if type(itemName) ~= "string" or itemName == "" then
        return false, nil
    end

    local char = getCharacter(lplr)
    local backpack = lplr:FindFirstChildOfClass("Backpack")
    local equippedTool = char and findToolInContainer(char, itemName) or nil
    if equippedTool then
        return true, equippedTool
    end

    local backpackTool = backpack and findToolInContainer(backpack, itemName) or nil
    if backpackTool then
        return true, backpackTool
    end

    return false, nil
end

function getHeldOrBackpackToolByKeywords(keywords)
    if type(keywords) ~= "table" or #keywords == 0 then
        return nil
    end

    local function matches(tool)
        if not tool or not tool:IsA("Tool") then
            return false
        end
        local loweredName = tool.Name:lower()
        for _, keyword in ipairs(keywords) do
            local loweredKeyword = tostring(keyword):lower()
            if loweredKeyword ~= "" and loweredName:find(loweredKeyword, 1, true) then
                return true
            end
        end
        return false
    end

    local char = getCharacter(lplr)
    if char then
        local heldTool = char:FindFirstChildOfClass("Tool")
        if matches(heldTool) then
            return heldTool
        end
        for _, tool in ipairs(char:GetChildren()) do
            if matches(tool) then
                return tool
            end
        end
    end

    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if matches(tool) then
                return tool
            end
        end
    end

    return nil
end

function getHeldOrBackpackBlockTool()
    return getHeldOrBackpackToolByKeywords({"wool", "clay", "stone", "plank", "obsidian", "concrete", "glass"})
end

function getHeldOrBackpackVoidDropTool()
    return getHeldOrBackpackToolByKeywords({"diamond", "emerald", "iron", "gold"})
end

function getHeldOrBackpackDaoTool()
    local _, tool = hasItem("dao")
    return tool
end

function equipToolIfNeeded(tool)
    local char = getCharacter(lplr)
    local hum = getHumanoid(char)
    if not tool or not hum or not char then
        return false
    end
    if tool.Parent == char then
        return true
    end
    local equipped = safeCall("EquipTool", function()
        hum:EquipTool(tool)
        return true
    end)
    if equipped then
        task.wait()
        return true
    end
    return false
end

function isDaoTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    local lowered = tool.Name:lower()
    return lowered:find("dao") ~= nil
end

function useDaoAbility()
    local char = getCharacter(lplr)
    if not char then return false end
    local dao = getHeldOrBackpackDaoTool()
    if not dao then return false end
    if not equipToolIfNeeded(dao) then
        return false
    end

    local used = false
    safeCall("DaoActivate", function()
        dao:Activate()
        used = true
    end)

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _, remote in ipairs(remotes:GetDescendants()) do
            if remote:IsA("RemoteEvent") and (remote.Name:lower():find("ability") or remote.Name:lower():find("use")) then
                safeCall("DaoRemoteString", function()
                    remote:FireServer(dao.Name)
                    used = true
                end)
                safeCall("DaoRemoteTable", function()
                    remote:FireServer({item = dao.Name})
                    used = true
                end)
            end
        end
    end

    return used
end


--====================================================
-- targeting helpers
--====================================================

function getTargetByFilters(range, attackPlayers, attackNPCs, ignoreTeammates)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    if not myHRP then
        return nil
    end
    local nearest
    local nearestDistance = range or math.huge

    if attackPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            local isSelf = player == lplr
            local sameTeam = player.Team ~= nil and lplr.Team ~= nil and player.Team == lplr.Team
            if not isSelf and (not ignoreTeammates or not sameTeam) then
                local targetChar = getCharacter(player)
                local targetHum = getHumanoid(targetChar)
                local targetHRP = getHRP(targetChar)
                if targetHum and targetHRP and targetHum.Health > 0 then
                    local distance = (targetHRP.Position - myHRP.Position).Magnitude
                    if distance < nearestDistance then
                        nearest = targetChar
                        nearestDistance = distance
                    end
                end
            end
        end
    end

    if attackNPCs then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= myChar then
                local targetHum = model:FindFirstChildOfClass("Humanoid")
                local targetHRP = model:FindFirstChild("HumanoidRootPart")
                if targetHum and targetHRP and targetHum.Health > 0 then
                    if not isPlayerCharacterModel(model) then
                        local distance = (targetHRP.Position - myHRP.Position).Magnitude
                        if distance < nearestDistance then
                            nearest = model
                            nearestDistance = distance
                        end
                    end
                end
            end
        end
    end

    return nearest, nearestDistance
end


function getNearestEnemy(range, ignoreTeam)
    local myChar = getCharacter(lplr)
    if not myChar then return nil, nil end
    local myTeam = ignoreTeam and lplr.Team or nil
    local myHRP = getHRP(myChar)
    if not myHRP then return nil, nil end

    local nearest = nil
    local shortest = range or math.huge


    for _, player in ipairs(Players:GetPlayers()) do
        if player == lplr then continue end
        if myTeam and player.Team == myTeam then continue end
        local char = getCharacter(player)
        local hrp = getHRP(char)
        if hrp then
            local hum = getHumanoid(char)
            if hum and hum.Health > 0 then
                local dist = (myHRP.Position - hrp.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    nearest = char
                end
            end
        end
    end


    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model ~= myChar then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                if not isPlayerCharacterModel(model) then
                    local dist = (myHRP.Position - hrp.Position).Magnitude
                    if dist < shortest then
                        shortest = dist
                        nearest = model
                    end
                end
            end
        end
    end

    return nearest, shortest
end

function getPlayerBedwarsTeamId(player)
    if not player then
        return nil
    end
    local directTeam = player:GetAttribute("Team")
        or player:GetAttribute("team")
        or player:GetAttribute("BedwarsTeam")
        or player:GetAttribute("bedwarsTeam")
    if directTeam ~= nil then
        return tostring(directTeam)
    end

    local character = player.Character
    if character then
        local charTeam = character:GetAttribute("Team")
            or character:GetAttribute("team")
            or character:GetAttribute("BedwarsTeam")
            or character:GetAttribute("bedwarsTeam")
        if charTeam ~= nil then
            return tostring(charTeam)
        end
    end

    return nil
end

function arePlayersTeammates(playerA, playerB)
    if not playerA or not playerB then
        return false
    end
    if playerA.Team ~= nil and playerB.Team ~= nil and playerA.Team == playerB.Team then
        return true
    end
    local teamA = getPlayerBedwarsTeamId(playerA)
    local teamB = getPlayerBedwarsTeamId(playerB)
    return teamA ~= nil and teamB ~= nil and teamA == teamB
end

function attackTargetWithBedwarsApi(targetCharacter)
    if not targetCharacter then
        return false
    end

    local controller = getCombatController()
    if not controller then
        return false
    end

    local targetHum = getHumanoid(targetCharacter)
    local targetRoot = getHRP(targetCharacter)
    if not targetHum or not targetRoot then
        return false
    end

    if type(controller.attackEntity) == "function" then
        return safeCall("KillAura_attackEntity", function()
            controller.attackEntity(controller, targetHum, targetRoot.Position)
            return true
        end) or false
    end

    if type(controller.AttackEntity) == "function" then
        return safeCall("KillAura_AttackEntity", function()
            controller.AttackEntity(controller, targetHum, targetRoot.Position)
            return true
        end) or false
    end

    if type(vapeFunctionTable.attackEntity) == "function" then
        return safeCall("KillAura_vapeAttackEntity", function()
            vapeFunctionTable.attackEntity(targetHum, targetRoot.Position)
            return true
        end) or false
    end
    return false
end



--====================================================
-- BedWars compatibility helpers inspired by CatVape
--====================================================

function getNearestRemoteByKeywords(keywords, classNames)
    if type(keywords) ~= "table" then
        return nil
    end

    local allowed = {}
    if type(classNames) == "table" then
        for _, className in ipairs(classNames) do
            allowed[className] = true
        end
    end

    local roots = {ReplicatedStorage}
    local netManaged = getNetManagedFolder()
    if netManaged then
        table.insert(roots, 1, netManaged)
    end

    for _, root in ipairs(roots) do
        for _, obj in ipairs(root:GetDescendants()) do
            local classAllowed = next(allowed) == nil or allowed[obj.ClassName] == true
            if classAllowed and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
                local loweredName = obj.Name:lower()
                local matched = true
                for _, keyword in ipairs(keywords) do
                    local loweredKeyword = tostring(keyword):lower()
                    if loweredKeyword ~= "" and not loweredName:find(loweredKeyword, 1, true) then
                        matched = false
                        break
                    end
                end
                if matched then
                    return obj
                end
            end
        end
    end

    return nil
end

function invokeBedwarsRemote(remote, payload)
    if not remote then
        return false
    end

    if remote:IsA("RemoteFunction") then
        return safeCall("InvokeBedwarsRemote", function()
            remote:InvokeServer(payload)
            return true
        end) or false
    end

    return safeCall("FireBedwarsRemote", function()
        remote:FireServer(payload)
        return true
    end) or false
end

function getToolItemType(tool)
    if not tool then
        return nil
    end
    return tool:GetAttribute("ItemType")
        or tool:GetAttribute("itemType")
        or tool:GetAttribute("Name")
        or tool.Name
end

function getBestToolForBlock(block)
    local lowered = block and block.Name:lower() or ""
    local keywords = {"pickaxe", "axe", "shears"}
    if lowered:find("wool", 1, true) then
        keywords = {"shears", "axe", "pickaxe"}
    elseif lowered:find("wood", 1, true) or lowered:find("plank", 1, true) then
        keywords = {"axe", "pickaxe", "shears"}
    elseif lowered:find("stone", 1, true) or lowered:find("ore", 1, true) or lowered:find("obsidian", 1, true) then
        keywords = {"pickaxe", "axe", "shears"}
    end

    local bestTool = nil
    local bestRank = math.huge
    local containers = {getCharacter(lplr), lplr:FindFirstChildOfClass("Backpack")}
    for _, container in ipairs(containers) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = tool.Name:lower()
                    for rank, keyword in ipairs(keywords) do
                        if name:find(keyword, 1, true) and rank < bestRank then
                            bestTool = tool
                            bestRank = rank
                        end
                    end
                end
            end
        end
    end

    return bestTool
end

function getNearestTaggedOrNamedObject(searchTerms, range, predicate)
    local char = getCharacter(lplr)
    local root = getHRP(char)
    if not root then
        return nil, nil
    end

    local loweredTerms = {}
    for _, term in ipairs(searchTerms or {}) do
        table.insert(loweredTerms, tostring(term):lower())
    end

    local nearest, nearestDistance = nil, range or math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local name = obj.Name:lower()
        local matched = #loweredTerms == 0
        for _, term in ipairs(loweredTerms) do
            if name:find(term, 1, true) or CollectionService:HasTag(obj, term) then
                matched = true
                break
            end
        end
        if matched and (not predicate or predicate(obj)) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local distance = (part.Position - root.Position).Magnitude
                if distance < nearestDistance then
                    nearest = obj
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest, nearestDistance
end

function getObjectPivotPosition(obj)
    if not obj then
        return nil
    end
    if obj:IsA("BasePart") then
        return obj.Position
    end
    local ok, pivot = pcall(function()
        return obj:GetPivot()
    end)
    if ok and pivot then
        return pivot.Position
    end
    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function getEffectiveCombatRange(baseRange)
    local effectiveRange = baseRange or 0
    if moduleStates["Reach"] and moduleSettings["Reach"] then
        effectiveRange = math.max(effectiveRange, moduleSettings["Reach"].hitRange or effectiveRange)
    end
    return effectiveRange
end

function getTargetAimPart(targetCharacter)
    return targetCharacter and (targetCharacter:FindFirstChild("Head") or getHRP(targetCharacter))
end

function isTargetWithinFov(targetCharacter, fovRadius)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getTargetAimPart(targetCharacter)
    if not myHRP or not targetPart then
        return false
    end

    local clampedFov = math.clamp(tonumber(fovRadius) or 360, 1, 360)
    if clampedFov >= 359 then
        return true
    end

    local direction = (targetPart.Position - myHRP.Position)
    if direction.Magnitude <= 0 then
        return true
    end
    local look = camera.CFrame.LookVector
    local dot = math.clamp(look:Dot(direction.Unit), -1, 1)
    local angle = math.deg(math.acos(dot))
    return angle <= (clampedFov / 2)
end

function hasLineOfSight(targetCharacter)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getTargetAimPart(targetCharacter)
    if not myHRP or not targetPart then
        return false
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {myChar}
    rayParams.IgnoreWater = true

    local direction = targetPart.Position - myHRP.Position
    local raycastResult = Workspace:Raycast(myHRP.Position, direction, rayParams)
    if not raycastResult then
        return true
    end

    return raycastResult.Instance and raycastResult.Instance:IsDescendantOf(targetCharacter)
end

function faceCharacterTarget(targetCharacter)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getTargetAimPart(targetCharacter)
    if not myHRP or not targetPart then
        return
    end

    local targetPosition = Vector3.new(targetPart.Position.X, myHRP.Position.Y, targetPart.Position.Z)
    myHRP.CFrame = CFrame.lookAt(myHRP.Position, targetPosition)
end

