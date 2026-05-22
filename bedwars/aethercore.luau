-- AetherCore :)

local consoleLog = (typeof(console) == "table" and type(console.log) == "function") and console.log or print
consoleLog("Welcome to AetherCore")
consoleLog("Script is loading...")

--====================================================
-- services and global references
--====================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local lplr = Players.LocalPlayer
local mouse = lplr:GetMouse()
local camera = Workspace.CurrentCamera



--====================================================
-- constants and default settings
--====================================================

local moduleSettings = {
    KillAura = {range = 14, swingSpeed = 18},
    AutoClicker = {cps = 10},
    Sprint = {omni = true},
    Speed = {speed = 23},
    Step = {maxHeight = 6, forwardCheckDistance = 2.6},
    SafeWalk = {maxDrop = 4.5},
    HighJump = {boost = 80},
    Aimbot = {
        fov = 160,
        smoothness = 0.55,
        predictionStrength = 1,
        arrowSpeed = 185,
        gravity = Workspace and Workspace.Gravity or 196.2,
        maxDistance = 260
    },
    Reach = {hitRange = 13, mineRange = 18, placeRange = 18},
    VerticalFly = {horizontalSpeed = 28, verticalSpeed = 45, groundOffset = 3.2, hoverHeight = 3.2},
    AntiDeath = {healthThreshold = 25, belowDuration = 2, slowMode = 1.5, voidOffset = 130},
    AntiHit = {slowMode = 1, riseWindow = 0.14, voidOffset = 130, antiDamageJitter = 2.2},
    FastBreak = {cooldown = 0.21, attemptsPerPulse = 2},
    AutoVoidDrop = {triggerOffset = 18, dropInterval = 0.45},
    FastPickup = {range = 14},
    AutoLeave = {staffOnly = true, leaveOnMatchEnd = true},
    Blink = {pulseSeconds = 0},
    AutoQueue = {delay = 1},
    AutoBuy = {sword = true, armor = true, upgrades = true},
    BedNuker = {range = 20},
    AutoPlay = {random = false},
    AutoShoot = {enabled = true},
    StaffDetector = {leaveOnDetect = false},
    AutoSuffocate = {range = 18},
    FPSBoost = {removeKillEffects = true, removeVisualizer = true},
    HitColor = {r = 1, g = 0, b = 0, a = 0.4},
    FOV = {value = 80},
    Viewmodel = {xOffset = 0, yOffset = 0, zOffset = 0},
    PickupRange = {range = 16},
    AutoPearl = {fallTrigger = 28},
    Crosshair = {imageId = 9943168532}
}

--====================================================
-- state tables (or wtv theyre called)
--====================================================

local moduleStates = {}
local moduleConnections = {}
local moduleKeybinds = {}
local moduleUi = {}
local moduleHandlers = {}
local guiEnabled = true
local autoToxicEnabled = false
local originalCharacterValues = {}
local SETTINGS_STORE_KEY = "AetherCoreClientConfigV1"
local AUTO_TOXIC_CONNECTION_KEY = "AetherCoreAutoToxicMessageConnection"
local mouseMoveRelative = type(mousemoverel) == "function" and mousemoverel or nil
local clipboardSetter = type(setclipboard) == "function" and setclipboard or nil
local sharedEnvironmentGetter = type(getgenv) == "function" and getgenv or nil
local autoToxicMessageConnection
local moduleConflictMap = { -- removed conflicts (creating a different system)
    Speed = {}
}


--====================================================
-- error logging
--====================================================

local function logError(scope, err)
    warn(string.format("[AetherCore][%s] %s", tostring(scope), tostring(err)))
end

local function safeCall(scope, fn, ...)
    local args = table.pack(...)
    local ok, result = xpcall(function()
        return fn(table.unpack(args, 1, args.n))
    end, debug.traceback)
    if not ok then
        logError(scope, result)
        return nil
    end
    return result
end


local warnedMissingObjects = {}
local function warnMissingOnce(key, message)
    if warnedMissingObjects[key] then
        return
    end
    warnedMissingObjects[key] = true
    warn(message)
end

local function getHandleInvItem(model)
    if not model then
        return nil
    end
    local handle = model:FindFirstChild("HandleInvItem")
    if not handle then
        warnMissingOnce("HandleInvItem:" .. model:GetFullName(), "[AetherCore] HandleInvItem missing for: " .. model:GetFullName())
        return nil
    end
    return handle
end

local function getHumanoidScaleValue(humanoid, scaleName)
    if not humanoid then
        return nil
    end
    local scaleValue = humanoid:FindFirstChild(scaleName)
    if not scaleValue then
        warnMissingOnce(scaleName .. ":" .. humanoid:GetFullName(), "[AetherCore] Missing humanoid scale '" .. scaleName .. "' for: " .. humanoid:GetFullName())
        return nil
    end
    return scaleValue
end

local function clampSetting(moduleName, settingName, value, min, max, fallback)
    local numeric = tonumber(value)
    if not numeric then
        numeric = fallback
    end
    local clamped = math.clamp(numeric or 0, min, max)
    moduleSettings[moduleName] = moduleSettings[moduleName] or {}
    moduleSettings[moduleName][settingName] = clamped
    return clamped
end


local function sayInChat(message)
    pcall(function()
        local channel = TextChatService.ChatInputBarConfiguration.TargetTextChannel
        if channel then
            channel:SendAsync(message)
        end
    end)
end



--====================================================
-- controller and remote resolvers
--====================================================

local KnitClient, CombatController, BedwarsShopController, BlockPlacementController, ClientHandler
local resolvedCombatController, resolvedBlockPlacementController
local cachedNetManagedFolder
local cachedDropItemRemote
local cachedDamageBlockRemote

local function fetchControllers()
    local knitPaths = {
        ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Knit"),
        ReplicatedStorage:FindFirstChild("rbxts_include") and ReplicatedStorage.rbxts_include:FindFirstChild("node_modules"):FindFirstChild("@rbxts"):FindFirstChild("net"):FindFirstChild("out")
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

local vapeFunctionTable = {}
local function refreshVapeFunctionTable()
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

local function getNetManagedFolder()
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

local function getDropItemRemote()
    if cachedDropItemRemote and cachedDropItemRemote.Parent then
        return cachedDropItemRemote
    end
    local netManaged = getNetManagedFolder()
    cachedDropItemRemote = netManaged and netManaged:FindFirstChild("DropItem")
    return cachedDropItemRemote
end

local function getDamageBlockRemote()
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

local function getCharacter(player)
    return player and player.Character
end

local function isPlayerCharacterModel(model)
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

local function getHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoidScale(humanoid, scaleName, defaultValue)
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

local function getCharacterAndHumanoid(player)
    local character = player and (player.Character or player.CharacterAdded:Wait())
    if not character then
        return nil, nil
    end
    return character, character:FindFirstChildOfClass("Humanoid")
end


--====================================================
-- movement/raycast helpers
--====================================================

local function raycastToGround(origin, ignoreList, castDistance)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList or {}
    return Workspace:Raycast(origin, Vector3.new(0, -(castDistance or 400), 0), params)
end

local function findNearestGroundPosition(origin, character, sampleRadius, sampleStep, verticalOffset)
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

local function getCombatController()
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

local function getBlockPlacementController()
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

local function doesToolNameMatch(tool, query)
    if not tool or not tool:IsA("Tool") or type(query) ~= "string" then
        return false
    end
    local normalizedToolName = tool.Name:lower()
    local normalizedQuery = query:lower()
    return normalizedToolName == normalizedQuery or normalizedToolName:find(normalizedQuery, 1, true) ~= nil
end

local function findToolInContainer(container, query)
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

local function hasItem(itemName)
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

local function getHeldOrBackpackToolByKeywords(keywords)
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

local function getHeldOrBackpackBlockTool()
    return getHeldOrBackpackToolByKeywords({"wool", "clay", "stone", "plank", "obsidian", "concrete", "glass"})
end

local function getHeldOrBackpackVoidDropTool()
    return getHeldOrBackpackToolByKeywords({"diamond", "emerald", "iron", "gold"})
end

local function getHeldOrBackpackDaoTool()
    local _, tool = hasItem("dao")
    return tool
end

local function equipToolIfNeeded(tool)
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

local function isDaoTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    local lowered = tool.Name:lower()
    return lowered:find("dao") ~= nil
end

local function useDaoAbility()
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

local function getTargetByFilters(range, attackPlayers, attackNPCs, ignoreTeammates)
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


local function getNearestEnemy(range, ignoreTeam)
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

local function getPlayerBedwarsTeamId(player)
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

local function arePlayersTeammates(playerA, playerB)
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

local function attackTargetWithBedwarsApi(targetCharacter)
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

local function getEffectiveCombatRange(baseRange)
    local effectiveRange = baseRange or 0
    if moduleStates["Reach"] and moduleSettings["Reach"] then
        effectiveRange = math.max(effectiveRange, moduleSettings["Reach"].hitRange or effectiveRange)
    end
    return effectiveRange
end

local function getTargetAimPart(targetCharacter)
    return targetCharacter and (targetCharacter:FindFirstChild("Head") or getHRP(targetCharacter))
end

local function isTargetWithinFov(targetCharacter, fovRadius)
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

local function hasLineOfSight(targetCharacter)
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

local function faceCharacterTarget(targetCharacter)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getTargetAimPart(targetCharacter)
    if not myHRP or not targetPart then
        return
    end

    local targetPosition = Vector3.new(targetPart.Position.X, myHRP.Position.Y, targetPart.Position.Z)
    myHRP.CFrame = CFrame.lookAt(myHRP.Position, targetPosition)
end



--====================================================
-- module manager
--====================================================

local function addConnection(moduleName, connection)
    if not moduleConnections[moduleName] then
        moduleConnections[moduleName] = {}
    end
    table.insert(moduleConnections[moduleName], connection)
end

local function cleanupModule(moduleName)
    if moduleConnections[moduleName] then
        for _, conn in ipairs(moduleConnections[moduleName]) do
            pcall(function() conn:Disconnect() end)
        end
        moduleConnections[moduleName] = nil
    end
end

local function disableConflictingModules(moduleName)
    local conflicts = moduleConflictMap[moduleName]
    if type(conflicts) ~= "table" then
        return
    end
    for _, conflictName in ipairs(conflicts) do
        if moduleStates[conflictName] then
            moduleStates[conflictName] = false
            if moduleHandlers[conflictName] then
                safeCall(conflictName .. "ConflictDisable", moduleHandlers[conflictName], false)
            end
            if moduleUi[conflictName] then
                moduleUi[conflictName].setEnabled(false)
            end
        end
    end
end

local function setModuleEnabled(moduleName, enabled)
    moduleStates[moduleName] = enabled
    if moduleName == "AutoToxic" then
        autoToxicEnabled = enabled
    end
    if moduleUi[moduleName] then
        moduleUi[moduleName].setEnabled(enabled)
    end
    if moduleHandlers[moduleName] then
        safeCall(moduleName .. "ProgrammaticToggle", moduleHandlers[moduleName], enabled)
    end
end


--====================================================
-- ui theme
--====================================================

-- ui colors stay the same as original look

local function performPrimaryClick()
    return safeCall("PrimaryClick", function()
        local mouseLocation = UserInputService:GetMouseLocation()
        local currentCamera = Workspace.CurrentCamera or camera
        if not currentCamera then
            return false
        end
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(mouseLocation, currentCamera.CFrame)
        task.wait()
        VirtualUser:Button1Up(mouseLocation, currentCamera.CFrame)
        return true
    end) or false
end



--====================================================
-- ui components
--====================================================

local function legacyCreateSlider(parent, name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 42)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueButton = Instance.new("TextButton")
    valueButton.Size = UDim2.new(0.3, -4, 0, 18)
    valueButton.Position = UDim2.new(0.7, 4, 0, 0)
    valueButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    valueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueButton.Font = Enum.Font.Gotham
    valueButton.TextSize = 12
    valueButton.Parent = frame
    Instance.new("UICorner", valueButton).CornerRadius = UDim.new(0, 7)

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 10)
    slider.Position = UDim2.new(0, 0, 0, 24)
    slider.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
    slider.Parent = frame
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 6)

    local fill = Instance.new("Frame")
    local range = max - min
    local percent = (default - min) / range
    fill.Size = UDim2.new(percent, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

    local dragging = false
    local function formatValue(v)
        if math.abs(v - math.floor(v)) < 0.001 then
            return tostring(math.floor(v))
        end
        return string.format("%.2f", v)
    end
    local function setValue(v)
        default = math.clamp(v, min, max)
        local newPercent = (default - min) / range
        TweenService:Create(fill, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(newPercent, 0, 1, 0)}):Play()
        valueButton.Text = formatValue(default)
        callback(default)
    end

    valueButton.Text = formatValue(default)

    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relativeX = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            local val = min + relativeX * range
            if math.abs(val - default) > 0.001 then
                setValue(val)
            end
        end
    end)

    local lastClick = 0
    valueButton.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick > 0.35 then
            lastClick = now
            return
        end
        lastClick = 0

        local inputBox = Instance.new("TextBox")
        inputBox.Size = valueButton.Size
        inputBox.Position = valueButton.Position
        inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        inputBox.Font = Enum.Font.Gotham
        inputBox.TextSize = 12
        inputBox.Text = valueButton.Text
        inputBox.ClearTextOnFocus = false
        inputBox.Parent = frame
        Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 7)
        inputBox:CaptureFocus()

        inputBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local typed = tonumber(inputBox.Text)
                if typed then
                    setValue(typed)
                end
            end
            inputBox:Destroy()
        end)
    end)

    return {
        GetValue = function() return default end,
        SetValue = function(v)
            setValue(v)
        end
    }
end

local function legacyCreateToggle(parent, name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("Frame")
    button.Size = UDim2.new(0, 36, 0, 20)
    button.Position = UDim2.new(1, -36, 0.5, -10)
    button.BackgroundColor3 = default and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(56, 56, 56)
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

    local buttonClick = Instance.new("TextButton")
    buttonClick.Size = UDim2.fromScale(1, 1)
    buttonClick.BackgroundTransparency = 1
    buttonClick.Text = ""
    buttonClick.Parent = button

    local stateText = Instance.new("TextLabel")
    stateText.Size = UDim2.new(1, 0, 1, 0)
    stateText.BackgroundTransparency = 1
    stateText.Text = default and "ON" or "OFF"
    stateText.TextColor3 = Color3.fromRGB(255, 255, 255)
    stateText.Font = Enum.Font.GothamBold
    stateText.TextSize = 9
    stateText.Parent = button

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = button
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default
    local function updateToggleVisual()
        TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = state and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(56, 56, 56)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        stateText.Text = state and "ON" or "OFF"
    end

    buttonClick.MouseButton1Click:Connect(function()
        state = not state
        updateToggleVisual()
        callback(state)
    end)

    return {
        GetValue = function() return state end,
        SetValue = function(v)
            state = v
            updateToggleVisual()
            callback(v)
        end
    }
end

local function legacyCreateDropdown(parent, name, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 80, 0, 20)
    button.Position = UDim2.new(1, -80, 0.5, -10)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.Text = default
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)

    local selected = default
    button.MouseButton1Click:Connect(function()

        local idx = table.find(options, selected) or 1
        idx = idx % #options + 1
        selected = options[idx]
        button.Text = selected
        callback(selected)
    end)

    return {
        GetValue = function() return selected end,
        SetValue = function(v)
            selected = v
            button.Text = v
            callback(v)
        end
    }
end

local function legacyCreateTextBox(parent, name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 80, 0, 20)
    box.Position = UDim2.new(1, -80, 0.5, -10)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.Text = default
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)

    box.FocusLost:Connect(function(enterPressed)
        callback(box.Text)
    end)

    return {
        GetValue = function() return box.Text end,
        SetValue = function(v)
            box.Text = v
            callback(v)
        end
    }
end





--====================================================
-- module definitions
--====================================================

-- combat modules

--// KillAura
-- category: combat
-- purpose: handles nearby target attacking.
moduleSettings["KillAura"] = {
    range = 14,
    fov = 360,
    swingSpeed = 18,
    faceTarget = false,
    requireSword = false,
    attackThroughWalls = true,
    ignoreTeammates = true,

    fovRadius = 360,
    attackPlayers = true,
    attackNPCs = false,
    fallbackToClickSimulation = false,

    targetSwitchDelay = 0.2
}

local killAuraLastSwing = 0

local function isSwordTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end

    local n = tool.Name:lower()
    return n:find("sword") ~= nil
        or n:find("blade") ~= nil
        or n:find("katana") ~= nil
        or n:find("dao") ~= nil
end

local function getHeldSword()
    local char = getCharacter(lplr)
    if not char then
        return nil
    end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool and isSwordTool(tool) then
        return tool
    end

    return nil
end

local function getHeldOrBackpackSword()
    local char = getCharacter(lplr)
    if char then
        local heldTool = char:FindFirstChildOfClass("Tool")
        if heldTool and isSwordTool(heldTool) then
            return heldTool
        end
    end

    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if not backpack then
        return nil
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and isSwordTool(tool) then
            return tool
        end
    end

    return nil
end

local function getKillAuraTarget(range, settings)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    if not myHRP then
        return nil
    end

    local bestTarget = nil
    local bestDistance = math.huge

    local function considerTarget(targetChar)
        if not targetChar then
            return
        end

        local hum = getHumanoid(targetChar)
        local root = getHRP(targetChar)
        if not hum or not root or hum.Health <= 0 then
            return
        end

        local distance = (root.Position - myHRP.Position).Magnitude
        if distance > range then
            return
        end

        if not isTargetWithinFov(targetChar, settings.fovRadius or settings.fov or 360) then
            return
        end

        if settings.attackThroughWalls == false and not hasLineOfSight(targetChar) then
            return
        end

        if distance < bestDistance then
            bestDistance = distance
            bestTarget = targetChar
        end
    end

    if settings.attackPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr then
                local sameTeam = player.Team ~= nil and lplr.Team ~= nil and player.Team == lplr.Team
                if not (settings.ignoreTeammates ~= false and sameTeam) then
                    considerTarget(getCharacter(player))
                end
            end
        end
    end

    if settings.attackNPCs then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= myChar then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local isPlayerModel = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then
                            isPlayerModel = true
                            break
                        end
                    end
                    if not isPlayerModel then
                        considerTarget(model)
                    end
                end
            end
        end
    end

    return bestTarget
end

local function toggleKillAura(enabled)
    cleanupModule("KillAura")
    if not enabled then
        return
    end

    local lockedTarget = nil
    local lastTargetSwitch = 0

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["KillAura"] then
            return
        end

        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myChar or not myHRP then
            return
        end

        local settings = moduleSettings["KillAura"] or {}
        if not settings.attackPlayers and not settings.attackNPCs then
            return
        end

        local sword = getHeldSword()
        if not sword then
            local backpackSword = getHeldOrBackpackSword()
            if backpackSword then
                equipToolIfNeeded(backpackSword)
                sword = getHeldSword()
            end
        end

        if settings.requireSword and not sword then
            return
        end

        local effectiveRange = getEffectiveCombatRange(settings.range or 14)

        local function isStillValidTarget(targetChar)
            if not targetChar then
                return false
            end

            local hum = getHumanoid(targetChar)
            local root = getHRP(targetChar)
            if not hum or not root or hum.Health <= 0 then
                return false
            end

            if (root.Position - myHRP.Position).Magnitude > effectiveRange then
                return false
            end

            if not isTargetWithinFov(targetChar, settings.fovRadius or settings.fov or 360) then
                return false
            end

            if settings.attackThroughWalls == false and not hasLineOfSight(targetChar) then
                return false
            end

            return true
        end

        if not isStillValidTarget(lockedTarget) then
            lockedTarget = nil
        end

        local now = tick()
        if not lockedTarget or (now - lastTargetSwitch >= (settings.targetSwitchDelay or 0.2)) then
            local newTarget = getKillAuraTarget(effectiveRange, settings)
            if newTarget ~= lockedTarget then
                lockedTarget = newTarget
                lastTargetSwitch = now
            end
        end

        if not lockedTarget then
            return
        end

        local swingDelay = 1 / math.max(settings.swingSpeed or 1, 1)
        if now - killAuraLastSwing < swingDelay then
            return
        end

        if settings.faceTarget then
            faceCharacterTarget(lockedTarget)
        end

        local attacked = attackTargetWithBedwarsApi(lockedTarget)

        if not attacked and sword then
            attacked = safeCall("KillAura_ToolActivate", function()
                sword:Activate()
                return true
            end) or false
        end

        if not attacked and settings.fallbackToClickSimulation then
            attacked = performPrimaryClick() or false
        end

        if attacked then
            killAuraLastSwing = now
        end
    end)

    addConnection("KillAura", connection)
end


--// Reach
-- category: combat
-- purpose: extends hit/mine/place ranges.
moduleSettings["Reach"] = {
    mode = "Both",
    hitRange = 12,
    mineRange = 12,
    placeRange = 12
}

local function toggleReach(enabled)
    cleanupModule("Reach")

    local function resetToolReach(tool)
        local grip = tool:FindFirstChild("AetherOriginalGripPos")
        if grip then
            tool.GripPos = Vector3.new(grip.Value.X, grip.Value.Y, grip.Value.Z)
            grip:Destroy()
        end

        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            local originalSize = handle:FindFirstChild("AetherOriginalHandleSize")
            if originalSize then
                handle.Size = Vector3.new(originalSize.Value.X, originalSize.Value.Y, originalSize.Value.Z)
                originalSize:Destroy()
            end
            handle.Massless = false
            handle.CanCollide = true
            handle.Transparency = 0
        end
    end

    local function applyToolReach(tool, rangeAmount)
        if not tool:IsA("Tool") then
            return
        end
        if not tool:FindFirstChild("AetherOriginalGripPos") then
            local originalGripPos = Instance.new("Vector3Value")
            originalGripPos.Name = "AetherOriginalGripPos"
            originalGripPos.Value = tool.GripPos
            originalGripPos.Parent = tool
        end

        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            if not handle:FindFirstChild("AetherOriginalHandleSize") then
                local originalHandleSize = Instance.new("Vector3Value")
                originalHandleSize.Name = "AetherOriginalHandleSize"
                originalHandleSize.Value = handle.Size
                originalHandleSize.Parent = handle
            end
            handle.Size = Vector3.new(math.max(handle.Size.X, 2), math.max(handle.Size.Y, 2), math.max(rangeAmount, 4))
            handle.Massless = true
            handle.CanCollide = false
            handle.Transparency = 0.35
        end

        local gripExtension = -math.max(rangeAmount - 4, 0)
        tool.GripPos = Vector3.new(tool.GripPos.X, tool.GripPos.Y, gripExtension)
    end

    local function forEachTool(callback)
        local char = getCharacter(lplr)
        local backpack = lplr:FindFirstChildOfClass("Backpack")
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    callback(tool)
                end
            end
        end
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    callback(tool)
                end
            end
        end
    end

    if not enabled then
        forEachTool(function(tool)
            resetToolReach(tool)
        end)
        lplr:SetAttribute("Reach", nil)
        return
    end

    local function applyReach()
        local char = getCharacter(lplr)
        if not char then return end
        local settings = moduleSettings["Reach"]

        if settings.mode == "Attribute" or settings.mode == "Both" then
            lplr:SetAttribute("Reach", math.max(settings.hitRange, settings.mineRange, settings.placeRange))
        else
            lplr:SetAttribute("Reach", nil)
        end

        local maxRange = math.max(settings.hitRange, settings.mineRange, settings.placeRange)
        forEachTool(function(tool)
            if settings.mode == "Handle" or settings.mode == "Both" then
                applyToolReach(tool, maxRange)
            else
                resetToolReach(tool)
            end
        end)
    end

    applyReach()
    addConnection("Reach", lplr.CharacterAdded:Connect(applyReach))
    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if backpack then
        addConnection("Reach", backpack.ChildAdded:Connect(function()
            if moduleStates["Reach"] then
                task.wait()
                applyReach()
            end
        end))
    end
end


--// Speed
-- category: blatant
-- purpose: applies custom movement speed.
moduleSettings["Speed"] = { speed = 24 }

local function toggleSpeed(enabled)
    cleanupModule("Speed")
    if not enabled then
        local char = getCharacter(lplr)
        if char then
            local hum = getHumanoid(char)
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
        end
        return
    end

    local function applySpeed()
        local char = getCharacter(lplr)
        if not char then return end
        local hum = getHumanoid(char)
        if hum then
            hum.WalkSpeed = moduleSettings["Speed"].speed
            hum.JumpPower = 60
        end
    end

    applySpeed()
    addConnection("Speed", lplr.CharacterAdded:Connect(applySpeed))
    addConnection("Speed", RunService.Heartbeat:Connect(function()
        if not moduleStates["Speed"] then return end
        applySpeed()
    end))
end

local function toggleSprint(enabled)
    cleanupModule("Sprint")
    if not enabled then return end
    local function applySprint()
        local char = getCharacter(lplr)
        local hum = char and getHumanoid(char)
        if not hum then return end
        hum:SetAttribute("AetherSprintForced", true)
        pcall(function()
            hum.WalkSpeed = math.max(hum.WalkSpeed, 16)
        end)
    end
    addConnection("Sprint", RunService.RenderStepped:Connect(function()
        if not moduleStates["Sprint"] then return end
        local char = getCharacter(lplr)
        local hum = char and getHumanoid(char)
        if not hum then return end
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0.01 then
            if (moduleSettings["Sprint"] or {}).omni then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            pcall(function()
                hum.AutoRotate = true
            end)
        end
    end))
    applySprint()
    addConnection("Sprint", lplr.CharacterAdded:Connect(function()
        task.wait(0.1)
        applySprint()
    end))
end

--// Step
-- category: blatant
-- purpose: steps up ledges more aggressively.
moduleSettings["Step"] = {
    maxHeight = 6,
    forwardCheckDistance = 2.6,
    stepCooldown = 0.09
}

local function toggleStep(enabled)
    cleanupModule("Step")
    moduleSettings["Step"].lastStepAt = 0

    local function applyStep(char)
        char = char or getCharacter(lplr)
        local hum = getHumanoid(char)
        if hum then
            hum.StepHeight = enabled and math.clamp(moduleSettings["Step"].maxHeight or 6, 2, 14) or 2
        end
    end

    if not enabled then
        applyStep()
        return
    end

    applyStep()
    addConnection("Step", lplr.CharacterAdded:Connect(function(char)
        applyStep(char)
    end))

    addConnection("Step", RunService.Heartbeat:Connect(function()
        if not moduleStates["Step"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        applyStep(char)

        if hum.MoveDirection.Magnitude < 0.05 then return end

        local settings = moduleSettings["Step"]
        local now = tick()
        local cooldown = math.clamp(settings.stepCooldown or 0.09, 0.03, 0.25)
        if now - (settings.lastStepAt or 0) < cooldown then return end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true

        local moveDir = hum.MoveDirection.Unit
        local forwardDist = math.clamp(settings.forwardCheckDistance or 2.6, 1.2, 5)

        -- check for wall ahead
        local wallHit = Workspace:Raycast(hrp.Position, moveDir * forwardDist, rayParams)
        if not wallHit or math.abs(wallHit.Normal.Y) > 0.45 then return end

        -- check there's a surface above the wall to land on
        local probeOrigin = wallHit.Position + moveDir * 1.1 + Vector3.new(0, settings.maxHeight + 2.5, 0)
        local surfaceHit = Workspace:Raycast(probeOrigin, Vector3.new(0, -(settings.maxHeight + 3.5), 0), rayParams)
        if not surfaceHit or surfaceHit.Normal.Y < 0.55 then return end

        local verticalDelta = surfaceHit.Position.Y - hrp.Position.Y
        if verticalDelta <= 0.6 or verticalDelta > settings.maxHeight + 0.35 then return end

        settings.lastStepAt = now

        -- launch upward with velocity instead of CFrame teleport
        local launchPower = math.clamp(verticalDelta * 8, 20, 80)
        hrp.AssemblyLinearVelocity = Vector3.new(
            hrp.AssemblyLinearVelocity.X,
            launchPower,
            hrp.AssemblyLinearVelocity.Z
        )
    end))
end

--// SafeWalk
-- category: utility
-- purpose: helps stop falling from edges.
moduleSettings["SafeWalk"] = {
    mode = "Normal",
    maxDrop = 4.5
}

local function toggleSafeWalk(enabled)
    cleanupModule("SafeWalk")
    if not enabled then return end

    local lastSafePosition
    local lastGroundedAt = 0

    addConnection("SafeWalk", RunService.Heartbeat:Connect(function()
        if not moduleStates["SafeWalk"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        local settings = moduleSettings["SafeWalk"]
        local moveDirection = hum.MoveDirection
        local horizontalSpeed = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
        if moveDirection.Magnitude < 0.02 and horizontalSpeed < 0.2 then
            return
        end

        local humanoidState = hum:GetState()
        local isAirborne = hum.FloorMaterial == Enum.Material.Air
            or humanoidState == Enum.HumanoidStateType.Freefall
            or humanoidState == Enum.HumanoidStateType.Jumping
        if isAirborne then
            return
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true

        local footRay = Workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rayParams)
        if footRay then
            lastSafePosition = hrp.Position
            lastGroundedAt = tick()
        end

        local probeDirection = moveDirection.Magnitude > 0 and moveDirection.Unit or Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
        local probeDistance = 1.9
        local probeOrigin = hrp.Position + (probeDirection * probeDistance)
        local edgeRay = Workspace:Raycast(probeOrigin + Vector3.new(0, 0.5, 0), Vector3.new(0, -math.max(settings.maxDrop or 4.5, 2), 0), rayParams)

        if edgeRay then
            return
        end

        if settings.mode == "Normal" then
            if lastSafePosition then
                hrp.CFrame = CFrame.new(lastSafePosition)
                hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            end
        else
            local shouldRescue = tick() - lastGroundedAt > 0.05 or hrp.AssemblyLinearVelocity.Y < -8
            if shouldRescue and lastSafePosition then
                hrp.CFrame = CFrame.new(lastSafePosition + Vector3.new(0, 1.5, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end))
end

moduleSettings["HighJump"] = {
    boost = 40
}

local function toggleHighJump(enabled)
    cleanupModule("HighJump")
    if not enabled then
        return
    end

    local char = getCharacter(lplr)
    local hum = getHumanoid(char)
    local hrp = getHRP(char)
    if not hum or not hrp then
        setModuleEnabled("HighJump", false)
        return
    end

    local boost = math.clamp(moduleSettings["HighJump"].boost or 40, 10, 180)
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, boost, hrp.AssemblyLinearVelocity.Z)
    task.delay(0.08, function()
        setModuleEnabled("HighJump", false)
    end)
end


moduleSettings["Fly"] = {
    horizontalSpeed = 40,
    verticalSpeed = 40,
    tpDownEnabled = false,
    tpDownInterval = 2.5,
    tpDownLast = 0,
    tpDownAirStart = nil,
    tpDownReturnDelay = 0.2
}

local function toggleFly(enabled)
    cleanupModule("Fly")
    if not enabled then
        local char = getCharacter(lplr)
        if char then
            local hrp = getHRP(char)
            if hrp then
                local bv = hrp:FindFirstChild("FlyVelocity")
                if bv then bv:Destroy() end
            end
        end
        return
    end

    local function setupFly()
        local char = getCharacter(lplr)
        if not char then return end
        local hrp = getHRP(char)
        if not hrp then return end

        local bv = hrp:FindFirstChild("FlyVelocity") or Instance.new("BodyVelocity")
        bv.Name = "FlyVelocity"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp

        return bv
    end

    local flyConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not moduleStates["Fly"] then return end
        local bv = setupFly()
        if not bv then return end
        local settings = moduleSettings["Fly"]

        local moveDir = Vector3.zero


        local camLook = camera.CFrame.LookVector
        local camRight = camera.CFrame.RightVector
        local flatLookVec = Vector3.new(camLook.X, 0, camLook.Z)
        local flatRightVec = Vector3.new(camRight.X, 0, camRight.Z)
        local flatLook = flatLookVec.Magnitude > 0 and flatLookVec.Unit or Vector3.new(0, 0, -1)
        local flatRight = flatRightVec.Magnitude > 0 and flatRightVec.Unit or Vector3.new(1, 0, 0)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += flatRight end


        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir += Vector3.new(0, 1, 0)
        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir -= Vector3.new(0, 1, 0)
        end

        local horizontal = Vector3.new(moveDir.X, 0, moveDir.Z)
        if horizontal.Magnitude > 1 then
            horizontal = horizontal.Unit
        end

        if moveDir.Magnitude > 0 then
            local hSpeed = settings.horizontalSpeed
            local vSpeed = settings.verticalSpeed
            local vel = Vector3.new(horizontal.X, moveDir.Y, horizontal.Z)
            vel = Vector3.new(vel.X * hSpeed, vel.Y * vSpeed, vel.Z * hSpeed)
            bv.Velocity = vel
        else
            bv.Velocity = Vector3.zero
        end


        if settings.tpDownEnabled then
            local now = tick()
            local char = getCharacter(lplr)
            local hrp = getHRP(char)
            local hum = getHumanoid(char)
            local isAirborne = hum and (hum.FloorMaterial == Enum.Material.Air or hum:GetState() == Enum.HumanoidStateType.Freefall)
            if not isAirborne then
                settings.tpDownAirStart = nil
            end
            if hrp and isAirborne then
                settings.tpDownAirStart = settings.tpDownAirStart or now
            end
            if hrp and isAirborne and settings.tpDownAirStart and now - settings.tpDownAirStart >= settings.tpDownInterval then
                settings.tpDownLast = now
                settings.tpDownAirStart = now
                local airbornePosition = hrp.Position
                local rayOrigin = hrp.Position
                local rayDirection = Vector3.new(0, -120, 0)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                raycastParams.FilterDescendantsInstances = {char}
                local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                if rayResult then
                    local targetPos = rayResult.Position + Vector3.new(0, 2.5, 0)
                    hrp.CFrame = CFrame.new(targetPos)
                    task.delay(settings.tpDownReturnDelay, function()
                        if moduleStates["Fly"] then
                            local liveChar = getCharacter(lplr)
                            local liveHrp = getHRP(liveChar)
                            if liveHrp then
                                liveHrp.CFrame = CFrame.new(airbornePosition)
                            end
                        end
                    end)
                end
            end
        end
    end)
    addConnection("Fly", flyConnection)
end

moduleSettings["VerticalFly"] = {
    horizontalSpeed = 28,
    verticalSpeed = 45,
    groundOffset = 3.2,
    antiKickSink = 1.4
}

local function toggleVerticalFly(enabled)
    cleanupModule("VerticalFly")
    local state = moduleSettings["VerticalFly"]

    local function resetCameraOffset()
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.zero
        end
    end

    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        resetCameraOffset()
        if state then
            state.virtualAltitude = 0
        end
        if hrp and state and state.lastVisualPosition then
            hrp.CFrame = CFrame.new(state.lastVisualPosition)
        end
        if hrp then
            local mover = hrp:FindFirstChild("VerticalFlyVelocity")
            if mover then mover:Destroy() end
        end
        return
    end

    local function ensureMover()
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if not hrp then return nil end
        local mover = hrp:FindFirstChild("VerticalFlyVelocity") or Instance.new("BodyVelocity")
        mover.Name = "VerticalFlyVelocity"
        mover.MaxForce = Vector3.new(9e4, 9e4, 9e4)
        mover.P = 8e3
        mover.Velocity = Vector3.zero
        mover.Parent = hrp
        return mover, hrp, char
    end

    addConnection("VerticalFly", RunService.Heartbeat:Connect(function(dt)
        if not moduleStates["VerticalFly"] then return end
        local mover, hrp, char = ensureMover()
        if not mover or not hrp then return end
        local settings = moduleSettings["VerticalFly"]

        local cameraLook = camera.CFrame.LookVector
        local cameraRight = camera.CFrame.RightVector
        local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
        local flatRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)
        flatLook = flatLook.Magnitude > 0 and flatLook.Unit or Vector3.new(0, 0, -1)
        flatRight = flatRight.Magnitude > 0 and flatRight.Unit or Vector3.new(1, 0, 0)

        local moveDirection = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += flatRight end

        local planarMove = Vector3.new(moveDirection.X, 0, moveDirection.Z)
        if planarMove.Magnitude > 1 then
            planarMove = planarMove.Unit
        end

        local verticalInput = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            verticalInput += 1
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            verticalInput -= 1
        end

        local hum = getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.zero
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end

        local horizontalSpeed = math.clamp(settings.horizontalSpeed or 28, 5, 80)
        local verticalSpeed = math.clamp(settings.verticalSpeed or 45, 8, 120)
        local antiKickSink = math.clamp(settings.antiKickSink or 1.4, 0, 6)

        local desiredVelocity = Vector3.new(planarMove.X * horizontalSpeed, verticalInput * verticalSpeed, planarMove.Z * horizontalSpeed)
        if verticalInput == 0 then
            desiredVelocity = Vector3.new(desiredVelocity.X, -antiKickSink, desiredVelocity.Z)
        end
        mover.Velocity = desiredVelocity
        state.lastVisualPosition = hrp.Position
    end))
end

moduleSettings["AntiDeath"] = {
    healthThreshold = 25,
    belowDuration = 2,
    slowMode = 1.5,
    voidOffset = 130
}

local function floorSnapPosition(origin, character, yOffset)
    local offset = yOffset or 3
    local ray = raycastToGround(origin + Vector3.new(0, 80, 0), {character}, 420)
    if ray then
        return ray.Position + Vector3.new(0, offset, 0), ray.Position.Y
    end
    local sampled = findNearestGroundPosition(origin, character, 14, 7, offset)
    return sampled, sampled and (sampled.Y - offset) or nil
end

local function toggleAntiDeath(enabled)
    cleanupModule("AntiDeath")
    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if hrp then
            hrp.Anchored = false
        end
        return
    end

    local state = {
        phase = "up",
        phaseUntil = 0,
        anchorCFrame = nil,
        anchorFloorY = nil
    }

    addConnection("AntiDeath", RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiDeath"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end
        local settings = moduleSettings["AntiDeath"]
        local now = tick()
        local lowHealth = hum.Health <= settings.healthThreshold

        if not lowHealth then
            if state.phase == "down" and state.anchorCFrame then
                local anchorPosition = state.anchorCFrame.Position
                local floorPosition = floorSnapPosition(anchorPosition + Vector3.new(0, 200, 0), char, 3)
                hrp.Anchored = false
                hrp.CFrame = CFrame.new(floorPosition or anchorPosition)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                task.wait()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            else
                hrp.Anchored = false
            end
            state.phase = "up"
            state.phaseUntil = 0
            state.anchorCFrame = nil
            state.anchorFloorY = nil
            return
        end

        if state.phaseUntil <= now then
            if state.phase == "up" then
                state.phase = "down"
                state.phaseUntil = now + settings.belowDuration
                state.anchorCFrame = hrp.CFrame
                local floorPosition, floorY = floorSnapPosition(hrp.Position, char, 3)
                if floorPosition then
                    state.anchorCFrame = CFrame.new(floorPosition)
                end
                state.anchorFloorY = floorY
            else
                state.phase = "up"
                state.phaseUntil = now + settings.slowMode
            end
        end

        if state.phase == "down" then
            local anchor = state.anchorCFrame or hrp.CFrame
            hrp.Anchored = true
            local floorY = state.anchorFloorY or (anchor.Position.Y - 3)
            hrp.CFrame = CFrame.new(anchor.Position.X, floorY - settings.voidOffset, anchor.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
        else
            hrp.Anchored = false
            if state.anchorCFrame then
                local anchorPosition = state.anchorCFrame.Position
                local floorPosition = floorSnapPosition(anchorPosition + Vector3.new(0, 200, 0), char, 3)
                hrp.CFrame = CFrame.new(floorPosition or anchorPosition)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                task.wait()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end))
end

moduleSettings["AntiHit"] = {
    slowMode = 1,
    riseWindow = 0.14,
    voidOffset = 130,
    antiDamageJitter = 2.2
}

local function toggleAntiHit(enabled)
    cleanupModule("AntiHit")
    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if hrp then
            hrp.Anchored = false
        end
        return
    end

    local state = {
        phase = "down",
        phaseUntil = 0,
        surfaceCFrame = nil,
        surfaceFloorY = nil,
        lastHealth = nil,
        damagePulseUntil = 0
    }

    addConnection("AntiHit", RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiHit"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        local settings = moduleSettings["AntiHit"]
        local now = tick()
        local downDuration = math.clamp(settings.slowMode or 1, 0.2, 5)
        local upDuration = math.clamp(settings.riseWindow or 0.14, 0.08, 0.35)
        local voidOffset = math.clamp(settings.voidOffset or 130, 60, 260)
        local jitter = math.clamp(settings.antiDamageJitter or 2.2, 0, 6)
        local currentHealth = hum.Health

        if state.lastHealth and currentHealth < state.lastHealth then
            state.damagePulseUntil = now + 1.2
        end
        state.lastHealth = currentHealth

        if state.phaseUntil <= now then
            if state.phase == "down" then
                state.phase = "up"
                state.phaseUntil = now + (state.damagePulseUntil > now and math.max(0.08, upDuration * 0.7) or upDuration)
                local surfacePosition, floorY = floorSnapPosition(hrp.Position + Vector3.new(0, 220, 0), char, 3)
                if surfacePosition then
                    state.surfaceCFrame = CFrame.new(surfacePosition)
                    state.surfaceFloorY = floorY
                elseif state.surfaceCFrame == nil then
                    state.surfaceCFrame = hrp.CFrame
                    state.surfaceFloorY = hrp.Position.Y - 3
                end
            else
                state.phase = "down"
                state.phaseUntil = now + downDuration
                local snapPosition, floorY = floorSnapPosition(hrp.Position, char, 3)
                if snapPosition then
                    state.surfaceCFrame = CFrame.new(snapPosition)
                    state.surfaceFloorY = floorY
                end
            end
        end

        if state.phase == "up" then
            hrp.Anchored = false
            if state.surfaceCFrame then
                local anchorPosition = state.surfaceCFrame.Position
                local resnapPosition = floorSnapPosition(anchorPosition + Vector3.new(0, 150, 0), char, 3)
                hrp.CFrame = CFrame.new(resnapPosition or anchorPosition)
            end
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.92, math.clamp(v.Y, -35, 70), v.Z * 0.92)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        else
            hrp.Anchored = false
            local surface = state.surfaceCFrame and state.surfaceCFrame.Position or hrp.Position
            local floorY = state.surfaceFloorY or (surface.Y - 3)
            local timeFactor = math.sin(now * 7.2) * 0.5 + 0.5
            local yJitter = jitter * timeFactor
            local xJitter = math.sin(now * 13.1) * (jitter * 0.25)
            local zJitter = math.cos(now * 11.7) * (jitter * 0.25)
            hrp.CFrame = CFrame.new(surface.X + xJitter, floorY - voidOffset - yJitter, surface.Z + zJitter)
            hrp.AssemblyLinearVelocity = Vector3.new(0, math.min(hrp.AssemblyLinearVelocity.Y, 0), 0)
        end
    end))
end

moduleSettings["FastBreak"] = {
    cooldown = 0.03,
    attemptsPerPulse = 2
}

local function toggleFastBreak(enabled)
    cleanupModule("FastBreak")
    if not enabled then return end

    moduleSettings["FastBreak"].lastBreak = 0
    addConnection("FastBreak", RunService.Heartbeat:Connect(function()
        if not moduleStates["FastBreak"] then return end
        local settings = moduleSettings["FastBreak"]
        local now = tick()
        if now - (settings.lastBreak or 0) < settings.cooldown then return end
        local target = mouse and mouse.Target
        if not target or not target:IsA("BasePart") then return end
        settings.lastBreak = now

        local targetPosition = target.Position
        local damageRemote = getDamageBlockRemote()
        if not damageRemote then return end

        for _ = 1, settings.attemptsPerPulse do
            safeCall("FastBreakDamageRemote", function()
                damageRemote:FireServer({
                    blockRef = {blockPosition = targetPosition},
                    hitPosition = targetPosition,
                    hitNormal = Vector3.new(0, 1, 0)
                })
            end)
        end
    end))
end

moduleSettings["AutoVoidDrop"] = {
    triggerOffset = 18,
    dropInterval = 0.45
}

local function toggleAutoVoidDrop(enabled)
    cleanupModule("AutoVoidDrop")
    if not enabled then return end

    moduleSettings["AutoVoidDrop"].lastDrop = 0
    moduleSettings["AutoVoidDrop"].dropRemote = getDropItemRemote()
    addConnection("AutoVoidDrop", RunService.Heartbeat:Connect(function()
        if not moduleStates["AutoVoidDrop"] then return end
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if not hrp then return end
        local settings = moduleSettings["AutoVoidDrop"]
        local now = tick()
        if now - (settings.lastDrop or 0) < settings.dropInterval then return end

        local nearbyGround = findNearestGroundPosition(hrp.Position, char, 10, 10, 0)
        if nearbyGround and hrp.Position.Y > nearbyGround.Y - settings.triggerOffset then
            return
        end
        if hrp.AssemblyLinearVelocity.Y > -8 then
            return
        end

        local dropRemote = settings.dropRemote or getDropItemRemote()
        settings.dropRemote = dropRemote
        if not dropRemote then return end

        local dropTargets = {"diamond", "iron", "emerald", "gold"}
        local dropTool = getHeldOrBackpackVoidDropTool()
        if dropTool then
            table.insert(dropTargets, dropTool.Name)
            equipToolIfNeeded(dropTool)
        end

        for _, resourceName in ipairs(dropTargets) do
            pcall(function()
                dropRemote:FireServer({item = resourceName, amount = 999})
            end)
            pcall(function()
                dropRemote:FireServer(resourceName)
            end)
        end
        settings.lastDrop = now
    end))
end


local function toggleESP(enabled)
    cleanupModule("ESP")
    if not enabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then
                obj:Destroy()
            end
        end
        return
    end

    local function removeESPFromModel(model)
        if not model then return end
        local old = model:FindFirstChild("ESP_Highlight")
        if old then
            old:Destroy()
        end
    end

    local function shouldHighlightModel(model)
        if not model then
            return false
        end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            return false
        end
        return true
    end

    local function addESPtoModel(model)
        if not shouldHighlightModel(model) then
            removeESPFromModel(model)
            return
        end
        if model:FindFirstChild("ESP_Highlight") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = model
        highlight.Parent = model
    end

    local function scanAndAddESP()
        if not moduleStates["ESP"] then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                addESPtoModel(player.Character)
            end
        end

        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local isPlayerChar = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then isPlayerChar = true break end
                    end
                    if not isPlayerChar then
                        addESPtoModel(model)
                    end
                else
                    removeESPFromModel(model)
                end
            end
        end
    end

    scanAndAddESP()
    addConnection("ESP", Players.PlayerAdded:Connect(function(player)
        addConnection("ESP", player.CharacterAdded:Connect(function(character)
            if moduleStates["ESP"] then
                addESPtoModel(character)
            end
        end))
    end))
    addConnection("ESP", Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            removeESPFromModel(player.Character)
        end
    end))
    local lastScan = 0
    addConnection("ESP", RunService.Heartbeat:Connect(function()
        if tick() - lastScan < 0.45 then return end
        lastScan = tick()
        scanAndAddESP()
    end))
end


moduleSettings["Tracers"] = { transparency = 0.5 }

local function clearTracerArtifacts()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Beam") and obj.Name == "TracerBeam" then
            obj:Destroy()
        elseif obj:IsA("Attachment") and (obj.Name == "TracerAttach0" or obj.Name == "TracerAttach1") then
            obj:Destroy()
        elseif obj:IsA("Part") and obj.Name == "TracerAnchorPart" then
            obj:Destroy()
        end
    end
end

local function toggleTracers(enabled)
    cleanupModule("Tracers")
    if not enabled then
        clearTracerArtifacts()
        return
    end
    clearTracerArtifacts()

    local function createTracerForModel(model)
        if not model or model:FindFirstChild("TracerBeam") then return end
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if not head then return end

        local anchorPart = Instance.new("Part")
        anchorPart.Name = "TracerAnchorPart"
        anchorPart.Size = Vector3.new(0.2, 0.2, 0.2)
        anchorPart.Transparency = 1
        anchorPart.Anchored = true
        anchorPart.CanCollide = false
        anchorPart.CanQuery = false
        anchorPart.CanTouch = false
        anchorPart.CFrame = camera.CFrame
        anchorPart.Parent = model

        local attach0 = Instance.new("Attachment")
        attach0.Name = "TracerAttach0"
        attach0.Parent = anchorPart

        local attach1 = Instance.new("Attachment")
        attach1.Name = "TracerAttach1"
        attach1.Parent = head

        local beam = Instance.new("Beam")
        beam.Name = "TracerBeam"
        beam.Attachment0 = attach0
        beam.Attachment1 = attach1
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        beam.Transparency = NumberSequence.new(moduleSettings["Tracers"].transparency)
        beam.Width0 = 0.1
        beam.Width1 = 0.1
        beam.Parent = model

        local updateConn = RunService.RenderStepped:Connect(function()
            if not moduleStates["Tracers"] then return end
            if not attach0 or not attach0.Parent then return end
            if not camera then return end
            anchorPart.CFrame = camera.CFrame
            beam.Transparency = NumberSequence.new(moduleSettings["Tracers"].transparency)
        end)
        addConnection("Tracers", updateConn)
    end

    local function scanAndAddTracers()
        if not moduleStates["Tracers"] then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                createTracerForModel(player.Character)
            end
        end
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local isPlayerChar = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then isPlayerChar = true break end
                    end
                    if not isPlayerChar then
                        createTracerForModel(model)
                    end
                end
            end
        end
    end

    scanAndAddTracers()
    local lastScan = 0
    addConnection("Tracers", RunService.Heartbeat:Connect(function()
        if tick() - lastScan < 0.45 then return end
        lastScan = tick()
        scanAndAddTracers()
    end))
end

local function toggleBedESP(enabled)
    cleanupModule("BedESP")
    if not enabled then return end
    local folder = Instance.new("Folder")
    folder.Name = "AetherCoreBedESP"
    folder.Parent = Workspace
    addConnection("BedESP", RunService.Heartbeat:Connect(function()
        if not moduleStates["BedESP"] then return end
        folder:ClearAllChildren()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower() == "bed" then
                local box = Instance.new("BoxHandleAdornment")
                box.Adornee = obj
                box.Size = obj.Size + Vector3.new(0.3, 0.3, 0.3)
                box.AlwaysOnTop = true
                box.ZIndex = 4
                box.Transparency = 0.55
                box.Color3 = Color3.fromRGB(255, 80, 80)
                box.Parent = folder
            end
        end
    end))
end

local function toggleNameTags(enabled)
    cleanupModule("NameTags")
    if not enabled then return end
    local tags = {}
    local function clearTag(plr)
        if tags[plr] then
            tags[plr]:Destroy()
            tags[plr] = nil
        end
    end
    addConnection("NameTags", RunService.Heartbeat:Connect(function()
        if not moduleStates["NameTags"] then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lplr and plr.Character then
                local head = plr.Character:FindFirstChild("Head")
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local root = getHRP(plr.Character)
                if head and hum and root then
                    local bb = tags[plr]
                    if not bb then
                        bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.fromOffset(220, 34)
                        bb.AlwaysOnTop = true
                        bb.StudsOffset = Vector3.new(0, 2.5, 0)
                        bb.Adornee = head
                        local label = Instance.new("TextLabel")
                        label.Name = "Label"
                        label.Size = UDim2.fromScale(1, 1)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamBold
                        label.TextScaled = true
                        label.Parent = bb
                        bb.Parent = head
                        tags[plr] = bb
                    end
                    local dist = math.floor((root.Position - camera.CFrame.Position).Magnitude / 3)
                    local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local r = math.floor(255 * (1 - hpRatio))
                    local g = math.floor(255 * hpRatio)
                    local tool = plr.Character:FindFirstChildOfClass("Tool")
                    local item = tool and (" | " .. tool.Name) or ""
                    bb.Label.TextColor3 = Color3.fromRGB(r, g, 40)
                    bb.Label.Text = string.format("%s [%d❤] [%db]%s", plr.DisplayName, math.floor(hum.Health), dist, item)
                else
                    clearTag(plr)
                end
            else
                clearTag(plr)
            end
        end
    end))
end


moduleSettings["AutoToxic"] = {
    finalKillMessage = "ez final kill",
    bedBreakMessage = "bed gone lol",
    gameWinMessage = "gg ez",
    enabledFinalKill = true,
    enabledBedBreak = true,
    enabledGameWin = true,
    autoGG = true,
    sponsorMode = false,
    customPhrases = "outplayed|too easy|nt"
}

local function setupAutoToxic()
    local sharedEnvironment = sharedEnvironmentGetter and sharedEnvironmentGetter() or nil
    local existingConnection = sharedEnvironment and sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY]
    if existingConnection then
        pcall(function()
            existingConnection:Disconnect()
        end)
        sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = nil
    end

    if autoToxicMessageConnection then
        autoToxicMessageConnection:Disconnect()
        autoToxicMessageConnection = nil
    end

    local lastMessageTime = 0
    local function sendToxicMessage(kind)
        if not autoToxicEnabled then
            return
        end
        if tick() - lastMessageTime < 1.5 then
            return
        end
        local settings = moduleSettings["AutoToxic"]
        local customList = {}
        for phrase in string.gmatch(tostring(settings.customPhrases or ""), "([^|]+)") do
            table.insert(customList, phrase)
        end
        local randomPhrase = #customList > 0 and customList[math.random(1, #customList)] or nil
        local sponsorSuffix = settings.sponsorMode and " | AetherCore" or ""
        if kind == "final" and settings.enabledFinalKill then
            sayInChat((randomPhrase or settings.finalKillMessage) .. sponsorSuffix)
            lastMessageTime = tick()
        elseif kind == "bed" and settings.enabledBedBreak then
            sayInChat(settings.bedBreakMessage .. sponsorSuffix)
            lastMessageTime = tick()
        elseif kind == "win" and settings.enabledGameWin then
            sayInChat((settings.autoGG and "gg " or "") .. settings.gameWinMessage .. sponsorSuffix)
            lastMessageTime = tick()
        end
    end

    if TextChatService and TextChatService.MessageReceived then
        autoToxicMessageConnection = TextChatService.MessageReceived:Connect(function(message)
            local text = (message.Text or ""):lower()
            local me = lplr.Name:lower()
            if text:find(me) and text:find("final kill") then
                sendToxicMessage("final")
            elseif text:find(me) and text:find("bed") and (text:find("break") or text:find("destroy")) then
                sendToxicMessage("bed")
            elseif text:find("victory") or text:find("you win") then
                sendToxicMessage("win")
            end
        end)
        if sharedEnvironment then
            sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = autoToxicMessageConnection
        end
    end
end
setupAutoToxic()


local function toggleAutoPlay(enabled)
    cleanupModule("AutoPlay")
    if not enabled then return end
    addConnection("AutoPlay", task.spawn(function()
        while moduleStates["AutoPlay"] do
            task.wait(math.max(0.2, tonumber((moduleSettings["AutoQueue"] or {}).delay) or 1))
            pcall(function()
                local queueRemote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("JoinQueue")
                if queueRemote then
                    local queueType = "bedwars_test_squads"
                    queueRemote:InvokeServer({queueType = queueType})
                end
            end)
        end
    end))
end

local function toggleAutoShoot(enabled)
    cleanupModule("AutoShoot")
    if not enabled then return end
    addConnection("AutoShoot", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates["AutoShoot"] then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.delay(0.05, performPrimaryClick)
        end
    end))
end

local function toggleStaffDetector(enabled)
    cleanupModule("StaffDetector")
    if not enabled then return end
    addConnection("StaffDetector", Players.PlayerAdded:Connect(function(player)
        if not moduleStates["StaffDetector"] or player == lplr then return end
        local rank = 0
        pcall(function() rank = player:GetRankInGroup(5774246) end)
        if rank >= 100 then
            warn("[AetherCore][StaffDetector] Staff detected: " .. player.Name .. " (" .. tostring(player.UserId) .. ")")
            if (moduleSettings["StaffDetector"] or {}).leaveOnDetect then
                pcall(function() lplr:Kick("AetherCore StaffDetector triggered.") end)
            end
        end
    end))
end

local function toggleTrapDisabler(enabled)
    moduleStates["TrapDisabler"] = enabled and true or false
end

local function toggleShopTierBypass(enabled)
    cleanupModule("ShopTierBypass")
    local state = rawget(_G, "AetherCoreShopTierBypassState") or {tiered = {}, nextTier = {}}
    _G.AetherCoreShopTierBypassState = state
    local shopItems = (((vapeFunctionTable or {}).ClientStore or {}).Shop and ((vapeFunctionTable or {}).ClientStore).Shop.ShopItems)
    if not shopItems then return end
    if enabled then
        for _, item in pairs(shopItems) do
            state.tiered[item] = item.tiered
            state.nextTier[item] = item.nextTier
            item.tiered = nil
            item.nextTier = nil
        end
    else
        for item, value in pairs(state.tiered) do item.tiered = value end
        for item, value in pairs(state.nextTier) do item.nextTier = value end
        state.tiered = {}
        state.nextTier = {}
    end
end

local function toggleAutoSuffocate(enabled)
    cleanupModule("AutoSuffocate")
    if not enabled then return end
    addConnection("AutoSuffocate", task.spawn(function()
        while moduleStates["AutoSuffocate"] do
            task.wait(0.1)
            if not moduleStates["Scaffold"] then
                local char = getCharacter(lplr)
                local hrp = getHRP(char)
                if hrp then
                    local range = math.clamp(tonumber((moduleSettings["AutoSuffocate"] or {}).range) or 18, 4, 24)
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= lplr and plr.Character and getHRP(plr.Character) then
                            local ehrp = getHRP(plr.Character)
                            if (ehrp.Position - hrp.Position).Magnitude <= range then
                                local pos = ehrp.Position + Vector3.new(0, 3, 0)
                                local damageBlockRemote = getDamageBlockRemote()
                                if damageBlockRemote then pcall(function() damageBlockRemote:InvokeServer({blockRef = {blockPosition = pos}}) end) end
                                break
                            end
                        end
                    end
                end
            end
        end
    end))
end

local function toggleFPSBoost(enabled)
    cleanupModule("FPSBoost")
    if enabled then
        Workspace.GlobalShadows = false
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    else
        Workspace.GlobalShadows = true
    end
end

local function toggleHitColor(enabled)
    cleanupModule("HitColor")
    if not enabled then return end
    addConnection("HitColor", RunService.Heartbeat:Connect(function()
        if not moduleStates["Hit Color"] then return end
        local settings = moduleSettings["HitColor"] or {}
        local color = Color3.new(settings.r or 1, settings.g or 0, settings.b or 0)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "_DamageHighlight_" then
                obj.FillColor = color
                obj.FillTransparency = settings.a or 0.4
            end
        end
    end))
end

local function toggleNoClickDelay(enabled)
    cleanupModule("NoClickDelay")
    if not enabled then
        return
    end
    addConnection("NoClickDelay", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates["NoClickDelay"] then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            performPrimaryClick()
        end
    end))
end

local function toggleFastPickup(enabled)
    cleanupModule("FastPickup")
    if not enabled then
        return
    end
    addConnection("FastPickup", RunService.Heartbeat:Connect(function()
        if not moduleStates["FastPickup"] then
            return
        end
        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myHRP then
            return
        end
        local pickupRemote = resolveClientRemote("PickupItemDrop")
        if not pickupRemote then
            return
        end
        local range = math.clamp(tonumber((moduleSettings["FastPickup"] or {}).range) or 14, 4, 30)
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {myChar}
        for _, part in ipairs(Workspace:GetPartBoundsInRadius(myHRP.Position, range, overlapParams)) do
            if part:IsA("BasePart") then
                local parent = part.Parent
                local nameLower = part.Name:lower()
                local parentLower = parent and parent.Name:lower() or ""
                if nameLower:find("drop") or nameLower:find("pickup") or parentLower:find("drop") then
                    pcall(function()
                        pickupRemote:FireServer({itemDrop = parent or part})
                    end)
                end
            end
        end
    end))
end

local function toggleAntiCrash(enabled)
    cleanupModule("AntiCrash")
    if not enabled then
        return
    end
    addConnection("AntiCrash", Workspace.DescendantAdded:Connect(function(obj)
        if not moduleStates["AntiCrash"] then
            return
        end
        if obj and obj.Name == "LightningStrike" then
            pcall(function() obj:Destroy() end)
        end
    end))
end

local function toggleAutoLeave(enabled)
    cleanupModule("AutoLeave")
    if not enabled then
        return
    end
    local function leaveMatch()
        pcall(function()
            lplr:Kick("AetherCore AutoLeave triggered.")
        end)
    end
    addConnection("AutoLeave", Players.PlayerAdded:Connect(function(player)
        if not moduleStates["AutoLeave"] then
            return
        end
        local isStaff = player:GetAttribute("isStaff") == true
            or tostring(player:GetAttribute("rank")):lower():find("moderator") ~= nil
            or tostring(player:GetAttribute("rank")):lower():find("admin") ~= nil
        if (moduleSettings["AutoLeave"] or {}).staffOnly and isStaff then
            leaveMatch()
        end
    end))
    addConnection("AutoLeave", TextChatService.MessageReceived:Connect(function(message)
        if not moduleStates["AutoLeave"] or not ((moduleSettings["AutoLeave"] or {}).leaveOnMatchEnd) then
            return
        end
        local text = string.lower(message.Text or "")
        if text:find("victory") or text:find("match ended") or text:find("game over") then
            leaveMatch()
        end
    end))
end


moduleSettings["Nuker"] = {
    mineBeds = true,
    mineIron = true,
    mineGold = true,
    mineDiamond = true,
    mineEmerald = true,
    mineRadius = 10
}

local function toggleNuker(enabled)
    cleanupModule("Nuker")
    if not enabled then return end

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["Nuker"] then return end
        local settings = moduleSettings["Nuker"]
        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myHRP then return end

        moduleSettings["Nuker"].lastScan = moduleSettings["Nuker"].lastScan or 0
        if tick() - moduleSettings["Nuker"].lastScan < 0.3 then return end
        moduleSettings["Nuker"].lastScan = tick()

        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {myChar}
        local nearbyParts = Workspace:GetPartBoundsInRadius(myHRP.Position, settings.mineRadius, overlapParams)
        local damageRemote = getDamageBlockRemote()
        if not damageRemote then return end
        local firedPositions = {}

        for _, obj in ipairs(nearbyParts) do
            if obj:IsA("BasePart") then
                local shouldMine = false
                local nameLower = obj.Name:lower()
                if settings.mineBeds and nameLower == "bed" and obj.Parent and obj.Parent.Name ~= lplr.Name then
                    shouldMine = true
                elseif settings.mineIron and nameLower:find("iron") then
                    shouldMine = true
                elseif settings.mineGold and nameLower:find("gold") then
                    shouldMine = true
                elseif settings.mineDiamond and nameLower:find("diamond") then
                    shouldMine = true
                elseif settings.mineEmerald and nameLower:find("emerald") then
                    shouldMine = true
                end

                if shouldMine then
                    local targetPosition = obj.Position
                    local key = string.format("%.3f|%.3f|%.3f", targetPosition.X, targetPosition.Y, targetPosition.Z)
                    if not firedPositions[key] then
                        firedPositions[key] = true
                        safeCall("NukerDamageRemote", function()
                            damageRemote:FireServer({
                                blockRef = {blockPosition = targetPosition},
                                hitPosition = targetPosition,
                                hitNormal = Vector3.new(0, 1, 0)
                            })
                        end)
                    end
                end
            end
        end
    end)
    addConnection("Nuker", connection)
end


moduleSettings["Scaffold"] = {
    allowTowering = true,
    placeAhead = 1
}

local function getTeamWoolName()
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

local function toggleScaffold(enabled)
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


moduleSettings["Aimbot"] = {
    enabled = true,
    fov = 160,
    smoothness = 0.55,
    snapStrength = 0.85,
    wallCheck = true,
    teamCheck = true,
    targetPart = "Head",
    maxDistance = 260,
    targetNPCs = true,
    predictionStrength = 1,
    arrowSpeed = 185,
    gravity = Workspace.Gravity
}

local function getAimbotTargetPart(character, requestedPart)
    if not character then
        return nil
    end
    if requestedPart == "Head" then
        return character:FindFirstChild("Head") or getHRP(character)
    end
    if requestedPart == "HumanoidRootPart" then
        return getHRP(character) or character:FindFirstChild("Head")
    end
    return character:FindFirstChild(requestedPart) or character:FindFirstChild("Head") or getHRP(character)
end

local function getProjectileVelocityEstimate(targetCharacter)
    local hrp = getHRP(targetCharacter)
    if not hrp then
        return Vector3.zero
    end
    local velocity = hrp.AssemblyLinearVelocity
    local hum = getHumanoid(targetCharacter)
    if hum then
        velocity += hum.MoveDirection * hum.WalkSpeed
    end
    return velocity
end

local function solveProjectileLead(origin, targetPosition, targetVelocity, projectileSpeed, gravity, predictionStrength)
    projectileSpeed = math.max(projectileSpeed or 185, 1)
    local gravityVector = Vector3.new(0, -(gravity or Workspace.Gravity), 0)
    local estimatedTime = math.clamp((targetPosition - origin).Magnitude / projectileSpeed, 0.05, 4)
    local strength = math.clamp(predictionStrength or 1, 0, 2)

    for _ = 1, 4 do
        local futurePosition = targetPosition + (targetVelocity * estimatedTime * strength)
        local displacement = futurePosition - origin
        estimatedTime = math.clamp(displacement.Magnitude / projectileSpeed, 0.05, 4)
    end

    local finalFuture = targetPosition + (targetVelocity * estimatedTime * strength)
    local gravityCompensation = gravityVector * (0.5 * estimatedTime * estimatedTime)
    return finalFuture - gravityCompensation
end

local function isVisibleForAimbot(targetCharacter, requestedPart)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getAimbotTargetPart(targetCharacter, requestedPart)
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

local function getAimbotCandidates(includeNPCs)
    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lplr then
            table.insert(candidates, {
                player = player,
                character = getCharacter(player)
            })
        end
    end

    if includeNPCs then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and not isPlayerCharacterModel(model) then
                table.insert(candidates, {
                    player = nil,
                    character = model
                })
            end
        end
    end

    return candidates
end

local function toggleAimbot(enabled)
    cleanupModule("Aimbot")
    if not enabled then return end

    addConnection("Aimbot", RunService.RenderStepped:Connect(function(deltaTime)
        if not moduleStates["Aimbot"] then return end
        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myChar or not myHRP then return end
        local settings = moduleSettings["Aimbot"]

        local bestCharacter
        local bestScreenDistance = math.huge
        local viewportCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

        for _, entry in ipairs(getAimbotCandidates(settings.targetNPCs ~= false)) do
            local player = entry.player
            local character = entry.character
            if player and settings.teamCheck and arePlayersTeammates(lplr, player) then
                continue
            end
            local hum = getHumanoid(character)
            local targetPart = getAimbotTargetPart(character, settings.targetPart)
            if hum and hum.Health > 0 and targetPart then
                local distance = (targetPart.Position - myHRP.Position).Magnitude
                if distance <= (settings.maxDistance or 260) then
                    if not settings.wallCheck or isVisibleForAimbot(character, settings.targetPart) then
                        local screenPosition, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local pixelDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - viewportCenter).Magnitude
                            if pixelDistance <= (settings.fov or 160) and pixelDistance < bestScreenDistance then
                                bestCharacter = character
                                bestScreenDistance = pixelDistance
                            end
                        end
                    end
                end
            end
        end

        if not bestCharacter then
            return
        end

        local targetPart = getAimbotTargetPart(bestCharacter, settings.targetPart)
        if not targetPart then
            return
        end
        local targetVelocity = getProjectileVelocityEstimate(bestCharacter)
        local predictedPosition = solveProjectileLead(
            camera.CFrame.Position,
            targetPart.Position,
            targetVelocity,
            settings.arrowSpeed,
            settings.gravity,
            settings.predictionStrength
        )

        local desiredDirection = (predictedPosition - camera.CFrame.Position)
        if desiredDirection.Magnitude <= 0.01 then
            return
        end
        desiredDirection = desiredDirection.Unit

        local targetViewportPoint, isOnScreen = camera:WorldToViewportPoint(predictedPosition)
        if mouseMoveRelative and isOnScreen then
            local viewportCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            local offset = Vector2.new(targetViewportPoint.X, targetViewportPoint.Y) - viewportCenter
            local smoothness = math.clamp(settings.smoothness or 0.55, 0.01, 1)
            local snapStrength = math.clamp(settings.snapStrength or 0.85, 0.1, 1)
            local interpolation = math.clamp((smoothness * snapStrength) * (deltaTime * 60), 0.05, 1)
            mouseMoveRelative(offset.X * interpolation, offset.Y * interpolation)
            return
        end

        local lookAtCFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + desiredDirection)
        local smoothness = math.clamp(settings.smoothness or 0.55, 0.01, 1)
        local alpha = math.clamp((smoothness * 1.35) * (deltaTime * 60), 0.06, 1)
        camera.CFrame = camera.CFrame:Lerp(lookAtCFrame, alpha)
    end))
end

moduleSettings["AimAssist"] = {
    speed = 0.1,
    range = 30
}

local function toggleAimAssist(enabled)
    cleanupModule("AimAssist")
    if not enabled then return end
    if not mouseMoveRelative then
        warn("[AetherCore][AimAssist] mousemoverel is unavailable in this executor.")
        return
    end

    local connection = RunService.RenderStepped:Connect(function(deltaTime)
        if not moduleStates["AimAssist"] then return end
        local settings = moduleSettings["AimAssist"]
        local nearest = getNearestEnemy(settings.range, true)
        if not nearest then return end
        local head = nearest:FindFirstChild("Head")
        if not head then return end

        local screenPos, onScreen = camera:WorldToScreenPoint(head.Position)
        if not onScreen then return end

        local targetPos = Vector2.new(screenPos.X, screenPos.Y)
        local mousePos = Vector2.new(mouse.X, mouse.Y)
        local smoothing = math.clamp(settings.speed * deltaTime * 60, 0.01, 1)
        local delta = (targetPos - mousePos) * smoothing
        mouseMoveRelative(delta.X, delta.Y)
    end)
    addConnection("AimAssist", connection)
end


moduleSettings["AutoClicker"] = { cps = 10 }

local function toggleAutoClicker(enabled)
    cleanupModule("AutoClicker")
    if not enabled then return end

    local holding = false
    local lastClick = 0

    local conn1 = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = true
        end
    end)
    local conn2 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = false
        end
    end)
    local conn3 = RunService.Heartbeat:Connect(function()
        if holding and moduleStates["AutoClicker"] then
            local now = tick()
            local delay = 1 / math.clamp(moduleSettings["AutoClicker"].cps, 1, 20)
            if now - lastClick >= delay then
                lastClick = now
                performPrimaryClick()
                local nearest = getTargetByFilters(18, true, false)
                if nearest then
                    attackTargetWithBedwarsApi(nearest)
                end
                local char = getCharacter(lplr)
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then
                    pcall(function() tool:Activate() end)
                end
            end
        end
    end)

    addConnection("AutoClicker", conn1)
    addConnection("AutoClicker", conn2)
    addConnection("AutoClicker", conn3)
end


moduleSettings["Velocity"] = {
    horizontalReduction = 100,
    verticalReduction = 100
}

local function toggleVelocity(enabled)
    cleanupModule("Velocity")
    if not enabled then return end

    local function applyVelocity(char)
        local hum = getHumanoid(char)
        local root = getHRP(char)
        if not hum or not root then
            return
        end
        local recentlyDamagedUntil = 0
        local lastHealth = hum.Health

        addConnection("Velocity", hum.HealthChanged:Connect(function(newHealth)
            if newHealth < lastHealth then
                recentlyDamagedUntil = tick() + 0.35
            end
            lastHealth = newHealth
        end))

        addConnection("Velocity", RunService.Heartbeat:Connect(function()
            if not moduleStates["Velocity"] or not root.Parent then return end
            if tick() > recentlyDamagedUntil then return end
            local settings = moduleSettings["Velocity"]
            local horizontalReduction = math.clamp(settings.horizontalReduction / 100, 0, 1)
            local verticalReduction = math.clamp(settings.verticalReduction / 100, 0, 1)
            local current = root.AssemblyLinearVelocity
            local moveDirection = hum.MoveDirection
            local baseHorizontal = moveDirection.Magnitude > 0 and moveDirection.Unit * hum.WalkSpeed or Vector3.zero
            local currentHorizontal = Vector3.new(current.X, 0, current.Z)
            local knockbackHorizontal = currentHorizontal - Vector3.new(baseHorizontal.X, 0, baseHorizontal.Z)
            local reducedHorizontal = knockbackHorizontal * (1 - horizontalReduction)
            local targetHorizontal = Vector3.new(baseHorizontal.X, 0, baseHorizontal.Z) + reducedHorizontal
            root.AssemblyLinearVelocity = Vector3.new(
                targetHorizontal.X,
                current.Y * (1 - verticalReduction),
                targetHorizontal.Z
            )
        end))
    end

    if lplr.Character then applyVelocity(lplr.Character) end
    addConnection("Velocity", lplr.CharacterAdded:Connect(applyVelocity))
end


moduleSettings["LongJump"] = {
    speed = 37,
    cameraDirection = false
}

local function toggleLongJump(enabled)
    cleanupModule("LongJump")

    local Value = {Value = math.clamp(tonumber(moduleSettings["LongJump"].speed) or 37, 1, 37)}
    local CameraDir = {Enabled = moduleSettings["LongJump"].cameraDirection == true}
    local start
    local JumpTick, JumpSpeed, Direction = tick(), 0, nil
    local projectileRemote = {InvokeServer = function(self, ...) return false end}

    local function flattenUnit(vec)
        if not vec then return Vector3.new(0, 0, -1) end
        local flat = Vector3.new(vec.X, 0, vec.Z)
        return flat.Magnitude > 0 and flat.Unit or Vector3.new(0, 0, -1)
    end

    local function launchProjectile(item, pos, proj, speed, dir)
        if not (item and pos and dir) then return end
        if projectileRemote and projectileRemote.InvokeServer then
            pcall(function()
                projectileRemote:InvokeServer(item, proj, proj, pos, pos, dir * speed)
            end)
        end
    end

    local LongJumpMethods = {
        cannon = function(_, _, dir)
            Direction = flattenUnit(dir)
            JumpSpeed = 5.25 * Value.Value
            JumpTick = tick() + 2.3
        end,
        catrewrite = function(_, _, dir)
            Direction = flattenUnit(dir)
            JumpSpeed = 4 * Value.Value
            JumpTick = tick() + 2.5
        end,
        fireball = function(item, pos, dir)
            launchProjectile(item, pos, "fireball", 60, dir)
        end,
        grappling_hook = function(item, pos, dir)
            launchProjectile(item, pos, "grappling_hook_projectile", 140, dir)
            Direction = flattenUnit(dir)
            JumpSpeed = 2.5 * Value.Value
            JumpTick = tick() + 2.5
        end,
        jade_hammer = function(_, _, dir)
            Direction = flattenUnit(dir)
            JumpSpeed = 1.4 * Value.Value
            JumpTick = tick() + 2.5
        end,
        tnt = function(item, pos, dir)
            if not (item and pos and dir and start) then return end
            start = Vector3.new(pos.X, start.Y, pos.Z) + (dir * (item.Name == "pirate_gunpowder_barrel" and 2.6 or 0.2))
        end,
        wood_dao = function(_, _, dir)
            Direction = flattenUnit(dir)
            JumpSpeed = 4.5 * Value.Value
            JumpTick = tick() + 2.4
        end
    }

    for _, v in {"stone_dao", "iron_dao", "diamond_dao", "emerald_dao"} do
        LongJumpMethods[v] = LongJumpMethods.wood_dao
    end
    LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
    LongJumpMethods.siege_tnt = LongJumpMethods.tnt
    LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt

    if not enabled then
        JumpTick = tick()
        Direction = nil
        JumpSpeed = 0
        return
    end

    local char = getCharacter(lplr)
    local hrp = getHRP(char)
    local hum = getHumanoid(char)
    if not (char and hrp and hum) then return end

    start = hrp.Position

    local function getLookVector()
        local source = CameraDir.Enabled and camera or hrp
        return flattenUnit(source.CFrame.LookVector)
    end

    local function getItemByName(name)
        local has, tool = hasItem(name)
        if has then return tool end
        return nil
    end

    local function triggerMethodFromInventory()
        local priority = {"emerald_dao", "diamond_dao", "iron_dao", "wood_dao", "stone_dao", "void_axe", "jade_hammer", "fireball", "grappling_hook", "cannon", "catrewrite", "siege_tnt", "pirate_gunpowder_barrel"}
        for _, itemName in ipairs(priority) do
            local item = getItemByName(itemName)
            local fn = LongJumpMethods[itemName]
            if item and fn then
                fn(item, start, getLookVector())
                return true
            end
        end
        return false
    end

    triggerMethodFromInventory()

    addConnection("LongJump", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates["LongJump"] then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.F then
            triggerMethodFromInventory()
        end
    end))

    addConnection("LongJump", RunService.PreSimulation:Connect(function(dt)
        if not moduleStates["LongJump"] then return end
        local currentChar = getCharacter(lplr)
        local root = getHRP(currentChar)
        local currentHum = getHumanoid(currentChar)
        if not (root and currentHum) then
            start = nil
            return
        end

        if JumpTick > tick() and Direction then
            root.AssemblyLinearVelocity = Direction * (currentHum.WalkSpeed + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
            if currentHum.FloorMaterial == Enum.Material.Air and not start then
                root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
            else
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
            end
            start = nil
        else
            if start then
                root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
            end
            root.AssemblyLinearVelocity = Vector3.zero
            JumpSpeed = 0
        end
    end))
end

local function toggleBlink(enabled)
    cleanupModule("Blink")
    if not enabled then return end
    local remoteCache = {}
    local pulseSeconds = math.max(0, tonumber((moduleSettings["Blink"] or {}).pulseSeconds) or 0)
    local metatable = getrawmetatable(game)
    if not metatable then return end
    local oldNamecall = metatable.__namecall
    setreadonly(metatable, false)
    metatable.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if moduleStates["Blink"] and method == "FireServer" and typeof(self) == "Instance" and self:IsA("RemoteEvent") then
            table.insert(remoteCache, {self, args})
            return nil
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(metatable, true)
    addConnection("Blink", {
        Disconnect = function()
            setreadonly(metatable, false)
            metatable.__namecall = oldNamecall
            setreadonly(metatable, true)
            for _, packet in ipairs(remoteCache) do
                pcall(function()
                    packet[1]:FireServer(table.unpack(packet[2]))
                end)
            end
            table.clear(remoteCache)
        end
    })
    if pulseSeconds > 0 then
        local lastPulse = tick()
        addConnection("Blink", RunService.Heartbeat:Connect(function()
            if tick() - lastPulse >= pulseSeconds then
                lastPulse = tick()
                for _, packet in ipairs(remoteCache) do
                    pcall(function()
                        packet[1]:FireServer(table.unpack(packet[2]))
                    end)
                end
                table.clear(remoteCache)
            end
        end))
    end
end

local function toggleAutoQueue(enabled)
    cleanupModule("AutoQueue")
    if not enabled then return end
    addConnection("AutoQueue", task.spawn(function()
        while moduleStates["AutoQueue"] do
            task.wait(math.max(0.1, tonumber((moduleSettings["AutoQueue"] or {}).delay) or 1))
            pcall(function()
                local queueRemote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("JoinQueue")
                if queueRemote then
                    queueRemote:InvokeServer({queueType = "bedwars_test_squads"})
                end
            end)
        end
    end))
end

local function toggleBedNuker(enabled)
    cleanupModule("BedNuker")
    if not enabled then return end
    addConnection("BedNuker", RunService.Heartbeat:Connect(function()
        if not moduleStates["BedNuker"] then return end
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if not hrp then return end
        local range = math.max(6, tonumber((moduleSettings["BedNuker"] or {}).range) or 28)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("bed") and obj:IsA("BasePart") and (obj.Position - hrp.Position).Magnitude <= range then
                local remote = getDamageBlockRemote()
                if remote then
                    pcall(function()
                        remote:InvokeServer({blockRef = {blockPosition = obj.Position}})
                    end)
                end
            end
        end
    end))
end

local function toggleAutoBuy(enabled)
    cleanupModule("AutoBuy")
    if not enabled then return end
    addConnection("AutoBuy", task.spawn(function()
        local function getInventoryItems()
            local inventoryGetter = vapeFunctionTable and vapeFunctionTable.getInventory
            if type(inventoryGetter) == "function" then
                local ok, inventory = pcall(inventoryGetter, lplr)
                if ok and type(inventory) == "table" and type(inventory.items) == "table" then
                    return inventory.items
                end
            end
            return {}
        end

        local function hasInventoryItem(itemType)
            if type(itemType) ~= "string" or itemType == "" then
                return false
            end
            for _, item in pairs(getInventoryItems()) do
                if type(item) == "table" and item.itemType == itemType and (tonumber(item.amount) or 0) > 0 then
                    return true
                end
            end
            return false
        end

        local function requestShopPurchase(itemType)
            if type(itemType) ~= "string" or itemType == "" then
                return false
            end
            local netManaged = getNetManagedFolder()
            if not netManaged then
                return false
            end
            local purchaseRemote = netManaged:FindFirstChild("BedwarsPurchaseItem")
            if not purchaseRemote then
                return false
            end
            local ok = pcall(function()
                purchaseRemote:InvokeServer({
                    shopItem = {itemType = itemType},
                    shopId = "ItemShop"
                })
            end)
            return ok
        end

        local function purchaseFirstMissing(itemTypes)
            for _, itemType in ipairs(itemTypes) do
                if not hasInventoryItem(itemType) then
                    if requestShopPurchase(itemType) then
                        return true
                    end
                end
            end
            return false
        end

        local swordOrder = {"wood_sword", "stone_sword", "iron_sword", "diamond_sword"}
        local armorOrder = {"leather_chestplate", "iron_chestplate", "diamond_chestplate"}
        local upgradeOrder = {"wood_pickaxe", "stone_pickaxe", "iron_pickaxe", "wood_axe", "stone_axe", "iron_axe"}

        while moduleStates["AutoBuy"] do
            local settings = moduleSettings["AutoBuy"] or {}
            local bought = false

            if settings.sword then
                bought = purchaseFirstMissing(swordOrder) or bought
            end
            if settings.armor then
                bought = purchaseFirstMissing(armorOrder) or bought
            end
            if settings.upgrades then
                bought = purchaseFirstMissing(upgradeOrder) or bought
            end

            task.wait(bought and 0.3 or 0.8)
        end
    end))
end

local function toggleOpenShop(enabled)
    cleanupModule("OpenShop")
    if enabled then
        pcall(function()
            local remote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("SetShownApp")
            if remote then
                remote:FireServer(5)
            end
        end)
        task.defer(function() moduleStates["OpenShop"] = false end)
    end
end

local function toggleOpenTeamUpgrades(enabled)
    cleanupModule("OpenTeamUpgrades")
    if enabled then
        pcall(function()
            local remote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("SetShownApp")
            if remote then
                remote:FireServer(4)
            end
        end)
        task.defer(function() moduleStates["OpenTeamUpgrades"] = false end)
    end
end


moduleSettings["NoFallDamage"] = {
    method = "Landing"
}

local function toggleNoFallDamage(enabled)
    cleanupModule("NoFallDamage")
    if not enabled then return end

    local function applyNoFall(char)
        local hum = getHumanoid(char)
        if not hum then
            return
        end
        if moduleSettings["NoFallDamage"].method == "Landing" then
            local conn = hum.StateChanged:Connect(function(old, new)
                if new == Enum.HumanoidStateType.Freefall then
                    task.delay(0.1, function()
                        local hrp = getHRP(char)
                        if moduleStates["NoFallDamage"] and hum.Parent and hrp then
                            local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0))
                            if ray then
                                hum:ChangeState(Enum.HumanoidStateType.Landed)
                            end
                        end
                    end)
                end
            end)
            addConnection("NoFallDamage", conn)
        elseif moduleSettings["NoFallDamage"].method == "NegateVelocity" then
            local conn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP(char)
                if hrp and hrp.AssemblyLinearVelocity.Y < -35 then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -2, hrp.AssemblyLinearVelocity.Z)
                end
            end)
            addConnection("NoFallDamage", conn)
        elseif moduleSettings["NoFallDamage"].method == "Teleport" then
            local conn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP(char)
                if hrp and hrp.AssemblyLinearVelocity.Y < -65 then
                    local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -25, 0))
                    if ray then
                        hrp.CFrame = CFrame.new(hrp.Position.X, ray.Position.Y + 4, hrp.Position.Z)
                    else
                        hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end)
            addConnection("NoFallDamage", conn)
        elseif moduleSettings["NoFallDamage"].method == "DaoExploit" then
            local daoCooldown = 0
            local charging = false
            local conn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP(char)
                if not hrp then return end

                local velocityY = hrp.AssemblyLinearVelocity.Y
                local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -30, 0))
                local groundDistance = ray and (hrp.Position.Y - ray.Position.Y) or math.huge
                local dao = getHeldOrBackpackDaoTool()

                if velocityY < -30 and groundDistance > 10 and tick() > daoCooldown and dao and not charging then
                    local activated = useDaoAbility()
                    if activated then
                        charging = true
                    end
                end

                if charging and (groundDistance < 8 or velocityY > -5) then
                    local held = char:FindFirstChildOfClass("Tool")
                    if held and isDaoTool(held) then
                        pcall(function()
                            held:Deactivate()
                        end)
                    end
                    charging = false
                    daoCooldown = tick() + 0.45
                end
            end)
            addConnection("NoFallDamage", conn)
        end
    end

    if lplr.Character then
        applyNoFall(lplr.Character)
    end
    addConnection("NoFallDamage", lplr.CharacterAdded:Connect(applyNoFall))
end

local function toggleNoFall(enabled)
    toggleNoFallDamage(enabled)
end


moduleSettings["AntiVoid"] = {
    method = "Normal",
    bouncePower = 100
}

local function createAntiVoidVisual()
    local indicator = Instance.new("Part")
    indicator.Name = "AntiVoidIndicator"
    indicator.Anchored = true
    indicator.CanCollide = false
    indicator.Size = Vector3.new(10, 0.5, 10)
    indicator.Material = Enum.Material.Neon
    indicator.BrickColor = BrickColor.new("Bright red")
    indicator.Transparency = 0.5
    indicator.Parent = Workspace
    return indicator
end

local function toggleAntiVoid(enabled)
    cleanupModule("AntiVoid")
    if not enabled then
        local indicator = Workspace:FindFirstChild("AntiVoidIndicator")
        if indicator then indicator:Destroy() end
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if hrp then
            local existingPull = hrp:FindFirstChild("AntiVoidPull")
            if existingPull then existingPull:Destroy() end
        end
        return
    end

    local indicator = createAntiVoidVisual()
    local pullVelocity = nil
    local rescueTarget = nil
    local voidTriggerY = nil
    local lastRescueUpdate = 0

    local function refreshVoidReference()
        local myChar = getCharacter(lplr)
        local hrp = getHRP(myChar)
        if not myChar or not hrp then
            return
        end
        local groundPos = findNearestGroundPosition(hrp.Position, myChar, 12, 6, 0)
        local referenceY = groundPos and groundPos.Y or hrp.Position.Y
        voidTriggerY = referenceY - 38
    end

    local function findRescueTarget(origin, character)
        local best = nil
        local bestScore = math.huge
        for radius = 12, 96, 12 do
            local candidate = findNearestGroundPosition(origin, character, radius, 6, 3)
            if candidate then
                local planarDistance = (Vector3.new(origin.X, 0, origin.Z) - Vector3.new(candidate.X, 0, candidate.Z)).Magnitude
                local heightPenalty = math.max(0, origin.Y - candidate.Y)
                local score = planarDistance + (heightPenalty * 0.25)
                if score < bestScore then
                    bestScore = score
                    best = candidate
                end
            end
        end
        return best
    end

    refreshVoidReference()
    addConnection("AntiVoid", lplr.CharacterAdded:Connect(function()
        task.wait(0.2)
        local existingIndicator = Workspace:FindFirstChild("AntiVoidIndicator")
        if not existingIndicator then
            indicator = createAntiVoidVisual()
        end
        refreshVoidReference()
    end))

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiVoid"] then return end
        local myChar = getCharacter(lplr)
        local hrp = getHRP(myChar)
        if not hrp then return end
        if not voidTriggerY then
            refreshVoidReference()
        end
        if not voidTriggerY then return end
        indicator.Position = Vector3.new(hrp.Position.X, voidTriggerY, hrp.Position.Z)

        if hrp.Position.Y <= voidTriggerY then
            local method = moduleSettings["AntiVoid"].method
            if method == "Normal" then
                if not rescueTarget or tick() - lastRescueUpdate > 0.4 then
                    rescueTarget = findRescueTarget(hrp.Position, myChar)
                    lastRescueUpdate = tick()
                end
                if rescueTarget then
                    hrp.CFrame = CFrame.new(rescueTarget + Vector3.new(0, 2, 0))
                    if pullVelocity then
                        pullVelocity:Destroy()
                    end
                    pullVelocity = Instance.new("BodyVelocity")
                    pullVelocity.Name = "AntiVoidPull"
                    pullVelocity.MaxForce = Vector3.new(2e5, 9e4, 2e5)
                    pullVelocity.Parent = hrp
                end
            elseif method == "Bounce" then
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, moduleSettings["AntiVoid"].bouncePower, hrp.AssemblyLinearVelocity.Z)
            end
        end

        if pullVelocity and rescueTarget then
            local goal = Vector3.new(rescueTarget.X, hrp.Position.Y, rescueTarget.Z)
            local planarDelta = goal - Vector3.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
            local upwardAssist = hrp.Position.Y < rescueTarget.Y + 3 and 10 or 0
            local planarVelocity = planarDelta.Magnitude > 0.5 and planarDelta.Unit * 22 or Vector3.zero
            pullVelocity.Velocity = Vector3.new(planarVelocity.X, upwardAssist, planarVelocity.Z)
            local closeToGround = hrp.Position.Y <= rescueTarget.Y + 5
            local closeToTarget = planarDelta.Magnitude < 3.5
            if closeToGround and closeToTarget then
                pullVelocity:Destroy()
                pullVelocity = nil
                rescueTarget = nil
                refreshVoidReference()
            end
        end

        if pullVelocity and rescueTarget then
            local horizontal = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(rescueTarget.X, 0, rescueTarget.Z)).Magnitude
            if horizontal < 4 and hrp.Position.Y <= rescueTarget.Y + 5 then
                pullVelocity:Destroy()
                pullVelocity = nil
            end
        end
    end)
    addConnection("AntiVoid", connection)
end


local function toggleInfiniteJump(enabled)
    cleanupModule("InfiniteJump")
    if not enabled then
        if lplr.Character then
            local hum = getHumanoid(lplr.Character)
            local original = originalCharacterValues["InfiniteJumpJumpPower"]
            if hum and original then
                hum.JumpPower = original
            elseif hum then
                hum.JumpPower = 50
            end
        end
        return
    end

    local function applyJump(char)
        local hum = getHumanoid(char)
        if hum then
            if not originalCharacterValues["InfiniteJumpJumpPower"] then
                originalCharacterValues["InfiniteJumpJumpPower"] = hum.JumpPower
            end
            hum.JumpPower = 0
        end
    end

    local connection = UserInputService.JumpRequest:Connect(function()
        if moduleStates["InfiniteJump"] and lplr.Character then
            local hum = getHumanoid(lplr.Character)
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)

    if lplr.Character then applyJump(lplr.Character) end
    addConnection("InfiniteJump", lplr.CharacterAdded:Connect(applyJump))
    addConnection("InfiniteJump", connection)
end





local palette = {
    deep = Color3.fromRGB(15, 15, 15),
    panel = Color3.fromRGB(24, 24, 24),
    module = Color3.fromRGB(31, 31, 31),
    hover = Color3.fromRGB(42, 42, 42),
    active = Color3.fromRGB(51, 32, 74),
    accent = Color3.fromRGB(164, 94, 233),
    text = Color3.fromRGB(255, 255, 255),
    secondary = Color3.fromRGB(170, 170, 170),
    danger = Color3.fromRGB(180, 65, 65)
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AetherCoreUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = lplr:WaitForChild("PlayerGui")

local panelFrames = {}
local moduleDefinitions = {}
local categoryPanels = {}
local categoryToggleButtons = {}
local categoryManualVisibility = {}
local categoryOrder = {"Combat", "Blatant", "Render", "Utility", "World", "Legend"}
local homeTabButton
local settingsTabButton
local scriptHubTabButton
local homeDashboardPanel
local settingsDashboardPanel
local scriptHubDashboardPanel
local activeSidebarTab = "Home"
local keybindListening = false
local searchText = ""
local settingsOpenByModule = {}
local loadedCategoryPositions = {}
local loadedModuleStates = {}
local saveClientSettings

moduleHandlers = {
    KillAura = toggleKillAura,
    Reach = toggleReach,
    AimAssist = toggleAimAssist,
    AutoClicker = toggleAutoClicker,
    Sprint = toggleSprint,
    AutoQueue = toggleAutoQueue,
    AutoPlay = toggleAutoPlay,
    AutoShoot = toggleAutoShoot,
    StaffDetector = toggleStaffDetector,
    TrapDisabler = toggleTrapDisabler,
    ShopTierBypass = toggleShopTierBypass,
    AutoSuffocate = toggleAutoSuffocate,
    ["FPS Boost"] = toggleFPSBoost,
    ["Hit Color"] = toggleHitColor,
    Velocity = toggleVelocity,
    Speed = toggleSpeed,
    Step = toggleStep,
    SafeWalk = toggleSafeWalk,
    HighJump = toggleHighJump,
    Fly = toggleFly,
    VerticalFly = toggleVerticalFly,
    LongJump = toggleLongJump,
    Aimbot = toggleAimbot,
    Scaffold = toggleScaffold,
    ESP = toggleESP,
    Tracers = toggleTracers,
    BedESP = toggleBedESP,
    NameTags = toggleNameTags,
    AutoToxic = function(enabled) autoToxicEnabled = enabled end,
    NoClickDelay = toggleNoClickDelay,
    AntiDeath = toggleAntiDeath,
    AntiHit = toggleAntiHit,
    NoFallDamage = toggleNoFallDamage,
    NoFall = toggleNoFall,
    AntiVoid = toggleAntiVoid,
    FastPickup = toggleFastPickup,
    AutoLeave = toggleAutoLeave,
    AntiCrash = toggleAntiCrash,
    InfiniteJump = toggleInfiniteJump,
    Blink = toggleBlink,
    BedNuker = toggleBedNuker,
    Nuker = toggleNuker,
    FastBreak = toggleFastBreak,
    AutoVoidDrop = toggleAutoVoidDrop
    ,
    AutoBuy = toggleAutoBuy,
    OpenShop = toggleOpenShop,
    OpenTeamUpgrades = toggleOpenTeamUpgrades
}

local function addCorner(target, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = target
end

local function stylePanel(panel)
    panel.BackgroundColor3 = palette.panel
    panel.BorderSizePixel = 0
    addCorner(panel, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 36)
    stroke.Thickness = 1
    stroke.Transparency = 0.2
    stroke.Parent = panel
end

local function styleDashboardCard(card)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    card.BorderSizePixel = 0
    addCorner(card, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(82, 58, 122)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = card
end

local function createDashboardSectionTitle(parent, text)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 0, 24)
    title.Position = UDim2.new(0, 12, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 17
    title.TextColor3 = palette.text
    title.Parent = parent
    return title
end

local function createPanel(name, size, position)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = size
    panel.Position = position
    panel.Parent = screenGui
    stylePanel(panel)
    panelFrames[name] = panel
    return panel
end

local function makeDraggable(frame, dragBar)
    local dragging = false
    local dragStart
    local startPos

    dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    dragBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            local cameraInstance = Workspace.CurrentCamera
            if cameraInstance then
                local viewport = cameraInstance.ViewportSize
                local maxX = math.max(10, viewport.X - frame.AbsoluteSize.X - 10)
                local maxY = math.max(10, viewport.Y - frame.AbsoluteSize.Y - 10)
                local clampedX = math.clamp(frame.Position.X.Offset, 10, maxX)
                local clampedY = math.clamp(frame.Position.Y.Offset, 10, maxY)
                frame.Position = UDim2.new(0, clampedX, 0, clampedY)
            end
            if saveClientSettings then
                saveClientSettings()
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local mainPanel = createPanel("MainPanel", UDim2.new(0, 190, 0, 430), UDim2.new(0, 80, 0, 120))
local topBar = createPanel("TopBar", UDim2.new(0, 350, 0, 40), UDim2.new(0, 285, 0, 120))
local statusPanel = createPanel("StatusPanel", UDim2.new(0, 265, 0, 24), UDim2.new(0, 80, 0, 560))

local mainTop = Instance.new("Frame")
mainTop.Size = UDim2.new(1, 0, 0, 40)
mainTop.BackgroundColor3 = palette.deep
mainTop.BorderSizePixel = 0
mainTop.Parent = mainPanel
addCorner(mainTop, 8)

local mainTitle = Instance.new("TextLabel")
mainTitle.Size = UDim2.new(1, -16, 1, 0)
mainTitle.Position = UDim2.new(0, 12, 0, 0)
mainTitle.BackgroundTransparency = 1
mainTitle.Text = "AetherCore"
mainTitle.TextXAlignment = Enum.TextXAlignment.Left
mainTitle.Font = Enum.Font.GothamBold
mainTitle.TextSize = 18
mainTitle.TextColor3 = palette.accent
mainTitle.Parent = mainTop

local mainList = Instance.new("Frame")
mainList.Size = UDim2.new(1, -10, 1, -50)
mainList.Position = UDim2.new(0, 5, 0, 45)
mainList.BackgroundTransparency = 1
mainList.Parent = mainPanel

local mainListLayout = Instance.new("UIListLayout")
mainListLayout.Padding = UDim.new(0, 6)
mainListLayout.Parent = mainList

local dashboardContent = Instance.new("Frame")
dashboardContent.Name = "DashboardContent"
dashboardContent.Size = UDim2.new(1, -295, 1, -170)
dashboardContent.Position = UDim2.new(0, 285, 0, 120)
dashboardContent.BackgroundTransparency = 1
dashboardContent.Parent = screenGui

local function createDashboardBase(name)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundColor3 = Color3.fromRGB(11, 11, 20)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = dashboardContent
    addCorner(panel, 12)

    local panelGradient = Instance.new("UIGradient")
    panelGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 13, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 15, 42))
    })
    panelGradient.Rotation = 180
    panelGradient.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(67, 48, 103)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = panel

    return panel
end

homeDashboardPanel = createDashboardBase("HomeDashboard")
settingsDashboardPanel = createDashboardBase("SettingsDashboard")
scriptHubDashboardPanel = createDashboardBase("ScriptHubDashboard")

local function setupHomeDashboardPanel()
    local welcomeCard = Instance.new("Frame")
    welcomeCard.Size = UDim2.new(1, -20, 0, 84)
    welcomeCard.Position = UDim2.new(0, 10, 0, 12)
    welcomeCard.Parent = homeDashboardPanel
    styleDashboardCard(welcomeCard)

    local welcomeTitle = Instance.new("TextLabel")
    welcomeTitle.Size = UDim2.new(1, -30, 0, 33)
    welcomeTitle.Position = UDim2.new(0, 15, 0, 12)
    welcomeTitle.BackgroundTransparency = 1
    welcomeTitle.Text = "Welcome back, Player!"
    welcomeTitle.TextXAlignment = Enum.TextXAlignment.Left
    welcomeTitle.TextColor3 = palette.text
    welcomeTitle.Font = Enum.Font.GothamBold
    welcomeTitle.TextSize = 30
    welcomeTitle.Parent = welcomeCard

    local welcomeSubtitle = Instance.new("TextLabel")
    welcomeSubtitle.Size = UDim2.new(1, -30, 0, 24)
    welcomeSubtitle.Position = UDim2.new(0, 15, 0, 47)
    welcomeSubtitle.BackgroundTransparency = 1
    welcomeSubtitle.Text = "AetherCore – Advanced BedWars Client"
    welcomeSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    welcomeSubtitle.TextColor3 = palette.secondary
    welcomeSubtitle.Font = Enum.Font.Gotham
    welcomeSubtitle.TextSize = 16
    welcomeSubtitle.Parent = welcomeCard

    local playerInfoCard = Instance.new("Frame")
    playerInfoCard.Size = UDim2.new(0.5, -16, 0, 222)
    playerInfoCard.Position = UDim2.new(0, 10, 0, 106)
    playerInfoCard.Parent = homeDashboardPanel
    styleDashboardCard(playerInfoCard)
    createDashboardSectionTitle(playerInfoCard, "Player Info")

    local playerInfoLines = {
        "Username: " .. lplr.Name,
        "User ID: " .. tostring(lplr.UserId),
        "Ping: Measuring...",
        "FPS: Measuring...",
        "Server: BedWars (Lobby)"
    }

    for index, text in ipairs(playerInfoLines) do
        local line = Instance.new("TextLabel")
        line.Size = UDim2.new(1, -24, 0, 25)
        line.Position = UDim2.new(0, 12, 0, 38 + ((index - 1) * 32))
        line.BackgroundTransparency = 1
        line.Text = text
        line.TextXAlignment = Enum.TextXAlignment.Left
        line.Font = Enum.Font.Gotham
        line.TextSize = 15
        line.TextColor3 = Color3.fromRGB(215, 215, 215)
        line.Parent = playerInfoCard

        if text:find("Ping:") == 1 then
            RunService.Heartbeat:Connect(function()
                if line.Parent then
                    local ping = math.floor(Players.LocalPlayer:GetNetworkPing() * 1000)
                    line.Text = ("Ping: %dms"):format(ping)
                end
            end)
        elseif text:find("FPS:") == 1 then
            local rollingDt = 1 / 60
            RunService.RenderStepped:Connect(function(dt)
                rollingDt = (rollingDt * 0.92) + (dt * 0.08)
                if line.Parent then
                    line.Text = ("FPS: %d"):format(math.clamp(math.floor(1 / math.max(rollingDt, 0.0001) + 0.5), 1, 999))
                end
            end)
        end
    end

    local quickActionsCard = Instance.new("Frame")
    quickActionsCard.Size = UDim2.new(0.5, -16, 0, 222)
    quickActionsCard.Position = UDim2.new(0.5, 6, 0, 106)
    quickActionsCard.Parent = homeDashboardPanel
    styleDashboardCard(quickActionsCard)
    createDashboardSectionTitle(quickActionsCard, "Quick Actions")

    local actionButtons = {
        "Rejoin Server",
        "Reset Character",
        "Server Hop",
        "Join Discord"
    }

    for index, label in ipairs(actionButtons) do
        local actionButton = Instance.new("TextButton")
        actionButton.Size = UDim2.new(1, -24, 0, 38)
        actionButton.Position = UDim2.new(0, 12, 0, 40 + ((index - 1) * 44))
        actionButton.BackgroundColor3 = index == 1 and Color3.fromRGB(109, 57, 201) or Color3.fromRGB(31, 31, 47)
        actionButton.Text = label
        actionButton.TextColor3 = palette.text
        actionButton.Font = Enum.Font.GothamSemibold
        actionButton.TextSize = 14
        actionButton.AutoButtonColor = false
        actionButton.Parent = quickActionsCard
        addCorner(actionButton, 8)
    end

    local statusCard = Instance.new("Frame")
    statusCard.Size = UDim2.new(1, -20, 0, 88)
    statusCard.Position = UDim2.new(0, 10, 1, -100)
    statusCard.Parent = homeDashboardPanel
    styleDashboardCard(statusCard)
    createDashboardSectionTitle(statusCard, "Status")

    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -24, 0, 24)
    statusText.Position = UDim2.new(0, 12, 0, 38)
    statusText.BackgroundTransparency = 1
    statusText.Text = "AetherCore is up to date!"
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextColor3 = Color3.fromRGB(103, 224, 132)
    statusText.Font = Enum.Font.GothamSemibold
    statusText.TextSize = 16
    statusText.Parent = statusCard

    local versionText = Instance.new("TextLabel")
    versionText.Size = UDim2.new(1, -24, 0, 18)
    versionText.Position = UDim2.new(0, 12, 0, 62)
    versionText.BackgroundTransparency = 1
    versionText.Text = "Version: v1.0.0"
    versionText.TextXAlignment = Enum.TextXAlignment.Left
    versionText.TextColor3 = palette.secondary
    versionText.Font = Enum.Font.Gotham
    versionText.TextSize = 13
    versionText.Parent = statusCard
end

setupHomeDashboardPanel()

local function setupScriptHubDashboardPanel()
    local scriptHubHeader = Instance.new("Frame")
    scriptHubHeader.Size = UDim2.new(1, -20, 0, 84)
    scriptHubHeader.Position = UDim2.new(0, 10, 0, 12)
    scriptHubHeader.Parent = scriptHubDashboardPanel
    styleDashboardCard(scriptHubHeader)

    local scriptHubTitle = Instance.new("TextLabel")
    scriptHubTitle.Size = UDim2.new(1, -30, 0, 34)
    scriptHubTitle.Position = UDim2.new(0, 15, 0, 12)
    scriptHubTitle.BackgroundTransparency = 1
    scriptHubTitle.Text = "AetherCore Assistant"
    scriptHubTitle.TextXAlignment = Enum.TextXAlignment.Left
    scriptHubTitle.TextColor3 = palette.text
    scriptHubTitle.Font = Enum.Font.GothamBold
    scriptHubTitle.TextSize = 30
    scriptHubTitle.Parent = scriptHubHeader

    local scriptHubSubtitle = Instance.new("TextLabel")
    scriptHubSubtitle.Size = UDim2.new(1, -30, 0, 24)
    scriptHubSubtitle.Position = UDim2.new(0, 15, 0, 48)
    scriptHubSubtitle.BackgroundTransparency = 1
    scriptHubSubtitle.Text = "Ask what a module does, how it works, or how to use AetherCore."
    scriptHubSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    scriptHubSubtitle.TextColor3 = palette.secondary
    scriptHubSubtitle.Font = Enum.Font.Gotham
    scriptHubSubtitle.TextSize = 16
    scriptHubSubtitle.Parent = scriptHubHeader

    local chatCard = Instance.new("Frame")
    chatCard.Size = UDim2.new(1, -20, 1, -120)
    chatCard.Position = UDim2.new(0, 10, 0, 106)
    chatCard.Parent = scriptHubDashboardPanel
    styleDashboardCard(chatCard)

    local chatLog = Instance.new("ScrollingFrame")
    chatLog.Size = UDim2.new(1, -24, 1, -74)
    chatLog.Position = UDim2.new(0, 12, 0, 12)
    chatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    chatLog.BorderSizePixel = 0
    chatLog.ScrollBarThickness = 5
    chatLog.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatLog.Parent = chatCard
    addCorner(chatLog, 8)

    local chatLayout = Instance.new("UIListLayout")
    chatLayout.Padding = UDim.new(0, 6)
    chatLayout.Parent = chatLog

    local chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(1, -118, 0, 44)
    chatInput.Position = UDim2.new(0, 12, 1, -56)
    chatInput.BackgroundColor3 = Color3.fromRGB(21, 21, 33)
    chatInput.BorderSizePixel = 0
    chatInput.PlaceholderText = "Ask: what does KillAura do? how does Scaffold work? what is AutoPearl?"
    chatInput.Text = ""
    chatInput.TextColor3 = palette.text
    chatInput.PlaceholderColor3 = palette.secondary
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 14
    chatInput.TextXAlignment = Enum.TextXAlignment.Left
    chatInput.ClearTextOnFocus = false
    chatInput.Parent = chatCard
    addCorner(chatInput, 8)

    local sendButton = Instance.new("TextButton")
    sendButton.Size = UDim2.new(0, 94, 0, 44)
    sendButton.Position = UDim2.new(1, -106, 1, -56)
    sendButton.BackgroundColor3 = Color3.fromRGB(109, 57, 201)
    sendButton.Text = "Send"
    sendButton.TextColor3 = palette.text
    sendButton.Font = Enum.Font.GothamSemibold
    sendButton.TextSize = 14
    sendButton.AutoButtonColor = false
    sendButton.Parent = chatCard
    addCorner(sendButton, 8)

    local moduleKnowledge = {
        ["killaura"] = "KillAura automatically attacks nearby valid targets while active.",
        ["autoclicker"] = "AutoClicker repeatedly performs clicks at the configured rate.",
        ["aimbot"] = "Aimbot adjusts aim toward a selected target while aiming.",
        ["reach"] = "Reach extends hit registration distance within this script's limits.",
        ["antihit"] = "AntiHit reduces how easily enemies can land hits on you.",
        ["antideath"] = "AntiDeath attempts to prevent death using this script's safety checks.",
        ["speed"] = "Speed increases movement speed while the module is enabled.",
        ["step"] = "Step lets your character climb higher ledges without jumping.",
        ["safewalk"] = "SafeWalk helps prevent accidental edge walk-offs.",
        ["highjump"] = "HighJump boosts jump height above normal movement.",
        ["verticalfly"] = "VerticalFly gives controlled vertical movement while active.",
        ["scaffold"] = "Scaffold places blocks under or ahead of you while moving.",
        ["fov"] = "FOV changes your field-of-view camera setting.",
        ["crosshair"] = "Crosshair customizes or overlays the on-screen crosshair.",
        ["viewmodel"] = "Viewmodel adjusts first-person hand or item view positioning.",
        ["bedplates"] = "BedPlates displays bed-related markers or plate visuals.",
        ["wineffect"] = "WinEffect plays a visual effect when a win condition is met.",
        ["fastpickup"] = "FastPickup improves how quickly nearby drops are collected.",
        ["fastbreak"] = "FastBreak reduces the time needed to break valid blocks.",
        ["autotoxic"] = "AutoToxic sends preset chat taunts automatically based on events.",
        ["interface"] = "Interface controls parts of the script UI presentation.",
        ["ui cleanup"] = "UI Cleanup removes or hides unnecessary on-screen UI clutter.",
        ["breaker"] = "Breaker automatically targets and breaks specific nearby objectives.",
        ["nuker"] = "Nuker rapidly breaks multiple valid nearby blocks.",
        ["autovoiddrop"] = "AutoVoidDrop automatically drops selected items into the void.",
        ["autopearl"] = "AutoPearl automatically uses a pearl in supported situations.",
        ["autobank"] = "AutoBank automatically deposits or stores resources when possible.",
        ["raventp"] = "RavenTP teleports using the script's RavenTP routine.",
        ["missiletp"] = "MissileTP teleports using the script's missile-based teleport routine.",
        ["armorswitch"] = "ArmorSwitch swaps armor sets based on module logic or conditions."
    }

    local moduleAliases = {
        ["kill aura"] = "killaura",
        ["ka"] = "killaura",
        ["scafold"] = "scaffold",
        ["auto pearl"] = "autopearl",
        ["autoperal"] = "autopearl",
        ["missle tp"] = "missiletp",
        ["missile tp"] = "missiletp",
        ["raven tp"] = "raventp",
        ["bed plates"] = "bedplates",
        ["ui cleanup"] = "ui cleanup",
        ["uicleanup"] = "ui cleanup",
        ["auto void drop"] = "autovoiddrop",
        ["fast break"] = "fastbreak",
        ["fast pickup"] = "fastpickup",
        ["auto toxic"] = "autotoxic",
        ["vertical fly"] = "verticalfly",
        ["high jump"] = "highjump",
        ["win effect"] = "wineffect"
    }

    local moduleCategoriesReply = "Combat: KillAura, AutoClicker, Aimbot, Reach, AntiHit, AntiDeath\nBlatant: Speed, Step, SafeWalk, HighJump, VerticalFly, Scaffold\nRender: FOV, Crosshair, Viewmodel, BedPlates, WinEffect\nUtility: FastPickup, FastBreak, AutoToxic, Interface, UI Cleanup\nWorld: Breaker, Nuker, AutoVoidDrop, AutoPearl, AutoBank\nLegend: RavenTP, MissileTP, ArmorSwitch"

    local function normalizeText(text)
        local value = (text or ""):lower()
        return value:gsub("[%s%p_%-]+", "")
    end

    local function buildLevenshteinMatrix(lenA, lenB)
        local matrix = {}
        for i = 0, lenA do
            matrix[i] = {[0] = i}
        end
        for j = 0, lenB do
            matrix[0][j] = j
        end
        return matrix
    end

    local function computeLevenshteinCell(matrix, left, right, i, j)
        local cost = left:sub(i, i) == right:sub(j, j) and 0 or 1
        local deletion = matrix[i - 1][j] + 1
        local insertion = matrix[i][j - 1] + 1
        local substitution = matrix[i - 1][j - 1] + cost
        matrix[i][j] = math.min(deletion, insertion, substitution)
    end

    local function levenshtein(a, b)
        local left = a or ""
        local right = b or ""
        local lenA = #left
        local lenB = #right
        if lenA == 0 then
            return lenB
        end
        if lenB == 0 then
            return lenA
        end

        local matrix = buildLevenshteinMatrix(lenA, lenB)
        for i = 1, lenA do
            for j = 1, lenB do
                computeLevenshteinCell(matrix, left, right, i, j)
            end
        end

        return matrix[lenA][lenB]
    end

    local function findClosestModule(prompt)
        local rawPrompt = (prompt or ""):lower()
        local normalizedPrompt = normalizeText(rawPrompt)

        for alias, canonical in pairs(moduleAliases) do
            local aliasRaw = alias:lower()
            local aliasNormalized = normalizeText(aliasRaw)
            if rawPrompt:find(aliasRaw, 1, true) or normalizedPrompt:find(aliasNormalized, 1, true) then
                return canonical
            end
        end

        for moduleName in pairs(moduleKnowledge) do
            local moduleNormalized = normalizeText(moduleName)
            if normalizedPrompt:find(moduleNormalized, 1, true) then
                return moduleName
            end
        end

        local bestMatch, bestDistance
        for moduleName in pairs(moduleKnowledge) do
            local moduleNormalized = normalizeText(moduleName)
            local distance = levenshtein(normalizedPrompt, moduleNormalized)
            if normalizedPrompt:find(moduleNormalized, 1, true) then
                distance = 0
            elseif #normalizedPrompt > #moduleNormalized and normalizedPrompt:find(moduleNormalized:sub(1, math.max(1, #moduleNormalized - 2)), 1, true) then
                distance = math.min(distance, 2)
            end

            if not bestDistance or distance < bestDistance then
                bestDistance = distance
                bestMatch = moduleName
            end
        end

        if bestDistance and bestDistance <= 2 then
            return bestMatch
        end

        return nil
    end

    local function addChatBubble(message, isUser)
        local bubble = Instance.new("TextLabel")
        bubble.Size = UDim2.new(1, -12, 0, 0)
        bubble.AutomaticSize = Enum.AutomaticSize.Y
        bubble.BackgroundColor3 = isUser and Color3.fromRGB(68, 45, 110) or Color3.fromRGB(29, 29, 45)
        bubble.BorderSizePixel = 0
        bubble.Text = (isUser and "You: " or "Aether AI: ") .. message
        bubble.TextColor3 = palette.text
        bubble.Font = Enum.Font.Gotham
        bubble.TextSize = 14
        bubble.TextWrapped = true
        bubble.TextXAlignment = Enum.TextXAlignment.Left
        bubble.TextYAlignment = Enum.TextYAlignment.Top
        bubble.Parent = chatLog
        addCorner(bubble, 8)

        task.wait()
        chatLog.CanvasSize = UDim2.new(0, 0, 0, chatLayout.AbsoluteContentSize.Y + 10)
        chatLog.CanvasPosition = Vector2.new(0, math.max(0, chatLog.CanvasSize.Y.Offset - chatLog.AbsoluteWindowSize.Y))
    end

    local function buildAssistantReply(prompt)
        local rawPrompt = (prompt or "")
        local loweredPrompt = rawPrompt:lower()
        local normalizedPrompt = normalizeText(rawPrompt)

        local asksForList = loweredPrompt:find("list modules", 1, true)
            or loweredPrompt:find("show modules", 1, true)
            or loweredPrompt:find("what modules", 1, true)
            or loweredPrompt:find("categories", 1, true)

        if asksForList then
            return moduleCategoriesReply
        end

        if loweredPrompt:find("help", 1, true) then
            return "Try asking: what does KillAura do? how does Scaffold work? what is AutoPearl? explain FastBreak. You can also ask: list modules."
        end

        local questionWords = {"what", "how", "does", "do", "work", "explain", "describe", "is"}
        local soundsLikeQuestion = false
        for _, word in ipairs(questionWords) do
            if loweredPrompt:find(word, 1, true) then
                soundsLikeQuestion = true
                break
            end
        end

        local moduleKey = findClosestModule(rawPrompt)
        if moduleKey and soundsLikeQuestion then
            return moduleKnowledge[moduleKey]
        end

        return "I can help with AetherCore modules and script usage. Ask what a module does, how it works, or type 'list modules' to see categories."
    end

    local function submitChatPrompt()
        local prompt = (chatInput.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if prompt == "" then
            return
        end
        addChatBubble(prompt, true)
        chatInput.Text = ""
        addChatBubble(buildAssistantReply(prompt), false)
    end

    sendButton.MouseButton1Click:Connect(submitChatPrompt)
    chatInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            submitChatPrompt()
        end
    end)

    addChatBubble("Hello. I am your AetherCore assistant. Ask me what a module does, how a module works, or how to use the script.", false)
end

setupScriptHubDashboardPanel()

local function setupSettingsDashboardPanel()
    local settingsHeader = Instance.new("Frame")
    settingsHeader.Size = UDim2.new(1, -20, 0, 84)
    settingsHeader.Position = UDim2.new(0, 10, 0, 12)
    settingsHeader.Parent = settingsDashboardPanel
    styleDashboardCard(settingsHeader)

    local settingsTitle = Instance.new("TextLabel")
    settingsTitle.Size = UDim2.new(1, -30, 0, 34)
    settingsTitle.Position = UDim2.new(0, 15, 0, 12)
    settingsTitle.BackgroundTransparency = 1
    settingsTitle.Text = "Settings"
    settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    settingsTitle.TextColor3 = palette.text
    settingsTitle.Font = Enum.Font.GothamBold
    settingsTitle.TextSize = 30
    settingsTitle.Parent = settingsHeader

    local settingsSubtitle = Instance.new("TextLabel")
    settingsSubtitle.Size = UDim2.new(1, -30, 0, 24)
    settingsSubtitle.Position = UDim2.new(0, 15, 0, 48)
    settingsSubtitle.BackgroundTransparency = 1
    settingsSubtitle.Text = "Configure AetherCore to your preference."
    settingsSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    settingsSubtitle.TextColor3 = palette.secondary
    settingsSubtitle.Font = Enum.Font.Gotham
    settingsSubtitle.TextSize = 16
    settingsSubtitle.Parent = settingsHeader

    local function createSettingsCard(titleText, items, positionScaleX)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0.3333, -14, 0, 236)
        card.Position = UDim2.new(positionScaleX, 10, 0, 106)
        card.Parent = settingsDashboardPanel
        styleDashboardCard(card)
        createDashboardSectionTitle(card, titleText)

        for index, itemText in ipairs(items) do
            local item = Instance.new("TextLabel")
            item.Size = UDim2.new(1, -24, 0, 32)
            item.Position = UDim2.new(0, 12, 0, 40 + ((index - 1) * 44))
            item.BackgroundColor3 = Color3.fromRGB(31, 31, 47)
            item.BorderSizePixel = 0
            item.Text = itemText
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.TextColor3 = Color3.fromRGB(225, 225, 225)
            item.Font = Enum.Font.Gotham
            item.TextSize = 14
            item.Parent = card
            addCorner(item, 8)
            item.Text = "  " .. itemText
        end
    end

    createSettingsCard("General", {"Notifications", "Auto Rejoin", "Auto Respawn", "Reduce Lag"}, 0)
    createSettingsCard("UI", {"Theme", "UI Scale", "UI Position", "Show Keybinds"}, 0.3333)
    createSettingsCard("Config", {"Save Config", "Load Config", "Reset Config", "Auto Save"}, 0.6666)

    local infoCard = Instance.new("Frame")
    infoCard.Size = UDim2.new(1, -20, 0, 84)
    infoCard.Position = UDim2.new(0, 10, 1, -96)
    infoCard.Parent = settingsDashboardPanel
    styleDashboardCard(infoCard)

    local infoTitle = Instance.new("TextLabel")
    infoTitle.Size = UDim2.new(1, -24, 0, 24)
    infoTitle.Position = UDim2.new(0, 12, 0, 12)
    infoTitle.BackgroundTransparency = 1
    infoTitle.Text = "Info"
    infoTitle.TextXAlignment = Enum.TextXAlignment.Left
    infoTitle.TextColor3 = palette.text
    infoTitle.Font = Enum.Font.GothamSemibold
    infoTitle.TextSize = 17
    infoTitle.Parent = infoCard

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -24, 0, 32)
    infoText.Position = UDim2.new(0, 12, 0, 40)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Settings are saved automatically and configuration changes can be restored at any time."
    infoText.TextWrapped = true
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextColor3 = palette.secondary
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 13
    infoText.Parent = infoCard
end

setupSettingsDashboardPanel()

local function setupTopBarAndStatusControls()
    local refs = {}

    refs.searchBox = Instance.new("TextBox")
    refs.searchBox.Size = UDim2.new(1, -130, 0, 26)
    refs.searchBox.Position = UDim2.new(0, 8, 0, 7)
    refs.searchBox.BackgroundColor3 = palette.module
    refs.searchBox.PlaceholderText = "Search modules..."
    refs.searchBox.ClearTextOnFocus = false
    refs.searchBox.Text = ""
    refs.searchBox.TextColor3 = palette.text
    refs.searchBox.PlaceholderColor3 = palette.secondary
    refs.searchBox.Font = Enum.Font.Gotham
    refs.searchBox.TextSize = 13
    refs.searchBox.Parent = topBar
    addCorner(refs.searchBox, 6)

    refs.closeButton = Instance.new("TextButton")
    refs.closeButton.Size = UDim2.new(0, 112, 0, 26)
    refs.closeButton.Position = UDim2.new(1, -120, 0, 7)
    refs.closeButton.BackgroundColor3 = palette.danger
    refs.closeButton.Text = "Uninject"
    refs.closeButton.TextColor3 = palette.text
    refs.closeButton.Font = Enum.Font.GothamBold
    refs.closeButton.TextSize = 12
    refs.closeButton.Parent = topBar
    addCorner(refs.closeButton, 6)

    refs.statusDiscord = Instance.new("TextButton")
    refs.statusDiscord.Size = UDim2.new(0, 150, 1, 0)
    refs.statusDiscord.BackgroundTransparency = 1
    refs.statusDiscord.Text = "discord.gg/mMMFRaUgDz"
    refs.statusDiscord.TextColor3 = palette.secondary
    refs.statusDiscord.Font = Enum.Font.Gotham
    refs.statusDiscord.TextSize = 11
    refs.statusDiscord.TextXAlignment = Enum.TextXAlignment.Left
    refs.statusDiscord.Parent = statusPanel

    refs.statusTime = Instance.new("TextLabel")
    refs.statusTime.Size = UDim2.new(0, 110, 1, 0)
    refs.statusTime.Position = UDim2.new(1, -110, 0, 0)
    refs.statusTime.BackgroundTransparency = 1
    refs.statusTime.Text = "Time: 0s"
    refs.statusTime.TextColor3 = palette.secondary
    refs.statusTime.Font = Enum.Font.Gotham
    refs.statusTime.TextSize = 11
    refs.statusTime.TextXAlignment = Enum.TextXAlignment.Right
    refs.statusTime.Parent = statusPanel

    refs.statusDiscord.MouseButton1Click:Connect(function()
        if clipboardSetter then
            safeCall("CopyDiscord", function()
                clipboardSetter("https://discord.gg/mMMFRaUgDz")
            end)
        else
            warn("[AetherCore][CopyDiscord] setclipboard is unavailable in this executor.")
        end
    end)

    local startTick = tick()
    RunService.RenderStepped:Connect(function()
        if refs.statusTime and refs.statusTime.Parent then
            refs.statusTime.Text = string.format("Time: %ds", math.floor(tick() - startTick))
        end
    end)

    return refs
end

local topBarStatusRefs = setupTopBarAndStatusControls()
local searchBox = topBarStatusRefs.searchBox
local closeButton = topBarStatusRefs.closeButton
local statusDiscord = topBarStatusRefs.statusDiscord
local statusTime = topBarStatusRefs.statusTime

makeDraggable(mainPanel, mainTop)
makeDraggable(topBar, topBar)
makeDraggable(statusPanel, statusPanel)

local function filterMatches(name)
    local q = string.lower(searchText or "")
    return q == "" or string.find(string.lower(name), q, 1, true) ~= nil
end

local function validateModuleSettings()
    clampSetting("KillAura", "range", moduleSettings.KillAura.range, 5, 20, 14)
    clampSetting("KillAura", "swingSpeed", moduleSettings.KillAura.swingSpeed, 1, 20, 18)
    clampSetting("AutoClicker", "cps", moduleSettings.AutoClicker.cps, 1, 20, 10)
    clampSetting("Speed", "speed", moduleSettings.Speed.speed, 16, 50, 24)
    clampSetting("Step", "maxHeight", moduleSettings.Step.maxHeight, 2, 14, 6)
    clampSetting("Step", "forwardCheckDistance", moduleSettings.Step.forwardCheckDistance, 1.5, 5, 2.6)
    clampSetting("SafeWalk", "maxDrop", moduleSettings.SafeWalk.maxDrop, 2, 10, 4.5)
    clampSetting("HighJump", "boost", moduleSettings.HighJump.boost, 10, 180, 40)
    clampSetting("Aimbot", "fov", moduleSettings.Aimbot.fov, 20, 450, 160)
    clampSetting("Aimbot", "smoothness", moduleSettings.Aimbot.smoothness, 0.01, 1, 0.55)
    clampSetting("Aimbot", "predictionStrength", moduleSettings.Aimbot.predictionStrength, 0, 2, 1)
    clampSetting("Aimbot", "arrowSpeed", moduleSettings.Aimbot.arrowSpeed, 40, 350, 185)
    clampSetting("Aimbot", "gravity", moduleSettings.Aimbot.gravity, 40, 350, Workspace.Gravity)
    clampSetting("Aimbot", "maxDistance", moduleSettings.Aimbot.maxDistance, 60, 400, 260)
    clampSetting("Reach", "hitRange", moduleSettings.Reach.hitRange, 6, 20, 12)
    clampSetting("Reach", "mineRange", moduleSettings.Reach.mineRange, 6, 20, 12)
    clampSetting("Reach", "placeRange", moduleSettings.Reach.placeRange, 6, 20, 12)
    clampSetting("VerticalFly", "horizontalSpeed", moduleSettings.VerticalFly.horizontalSpeed, 8, 60, 28)
    clampSetting("VerticalFly", "verticalSpeed", moduleSettings.VerticalFly.verticalSpeed, 10, 120, 45)
    clampSetting("VerticalFly", "groundOffset", moduleSettings.VerticalFly.groundOffset or moduleSettings.VerticalFly.hoverHeight, 1, 8, 3.2)
    moduleSettings.AntiDeath.healthThreshold = math.max(1, tonumber(moduleSettings.AntiDeath.healthThreshold) or 25)
    clampSetting("AntiDeath", "belowDuration", moduleSettings.AntiDeath.belowDuration, 0.5, 4, 2)
    clampSetting("AntiDeath", "slowMode", moduleSettings.AntiDeath.slowMode, 0.2, 5, 1.5)
    clampSetting("AntiDeath", "voidOffset", moduleSettings.AntiDeath.voidOffset, 60, 250, 130)
    clampSetting("AntiHit", "slowMode", moduleSettings.AntiHit.slowMode, 0.2, 5, 1)
    clampSetting("AntiHit", "riseWindow", moduleSettings.AntiHit.riseWindow, 0.08, 0.35, 0.14)
    clampSetting("AntiHit", "voidOffset", moduleSettings.AntiHit.voidOffset, 60, 260, 130)
    clampSetting("AntiHit", "antiDamageJitter", moduleSettings.AntiHit.antiDamageJitter, 0, 6, 2.2)
    clampSetting("FastBreak", "cooldown", moduleSettings.FastBreak.cooldown, 0, 0.3, 0.03)
    clampSetting("FastBreak", "attemptsPerPulse", moduleSettings.FastBreak.attemptsPerPulse, 1, 6, 2)
    clampSetting("AutoVoidDrop", "triggerOffset", moduleSettings.AutoVoidDrop.triggerOffset, 4, 60, 18)
    clampSetting("AutoVoidDrop", "dropInterval", moduleSettings.AutoVoidDrop.dropInterval, 0.1, 2, 0.45)
end

--====================================================
-- settings save and load system
--====================================================

saveClientSettings = function()
    safeCall("SaveClientSettings", function()
        local payload = {
            keybinds = {},
            moduleStates = {},
            settings = moduleSettings,
            categoryPositions = {}
        }
        for moduleName, key in pairs(moduleKeybinds) do
            payload.keybinds[moduleName] = key and key.Name or nil
        end
        for moduleName, enabled in pairs(moduleStates) do
            payload.moduleStates[moduleName] = enabled == true
        end
        for categoryName, panel in pairs(categoryPanels) do
            payload.categoryPositions[categoryName] = {x = panel.Position.X.Offset, y = panel.Position.Y.Offset}
        end
        local encoded = HttpService:JSONEncode(payload)
        if sharedEnvironmentGetter then
            sharedEnvironmentGetter()[SETTINGS_STORE_KEY] = encoded
        end
    end)
end

local function loadClientSettings()
    safeCall("LoadClientSettings", function()
        local raw = sharedEnvironmentGetter and sharedEnvironmentGetter()[SETTINGS_STORE_KEY]
        if type(raw) ~= "string" then return end
        local decoded = HttpService:JSONDecode(raw)
        if type(decoded) ~= "table" then return end
        if type(decoded.keybinds) == "table" then
            for moduleName, keyName in pairs(decoded.keybinds) do
                if Enum.KeyCode[keyName] then
                    moduleKeybinds[moduleName] = Enum.KeyCode[keyName]
                end
            end
        end
        if type(decoded.moduleStates) == "table" then
            for moduleName, enabled in pairs(decoded.moduleStates) do
                if type(enabled) == "boolean" then
                    loadedModuleStates[moduleName] = enabled
                end
            end
        end
        if type(decoded.settings) == "table" then
            for moduleName, values in pairs(decoded.settings) do
                if moduleSettings[moduleName] and type(values) == "table" then
                    for key, value in pairs(values) do
                        moduleSettings[moduleName][key] = value
                    end
                end
            end
        end
        if type(decoded.categoryPositions) == "table" then
            loadedCategoryPositions = decoded.categoryPositions
        end
    end)
    validateModuleSettings()
end
loadClientSettings()

--====================================================
-- startup
--====================================================

-- startup stays at the bottom so it is easy to see load order

--====================================================
-- windows and category creation
--====================================================

local moduleRuntime = {}

local function setScreenGuiEnabled(enabled)
    if screenGui and screenGui.Parent then
        screenGui.Enabled = enabled
    end
end

local function toggleFOV(enabled)
    cleanupModule("FOV")
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if enabled then
        moduleRuntime.FOVOriginal = cam.FieldOfView
        cam.FieldOfView = moduleSettings.FOV.value
    else
        cam.FieldOfView = moduleRuntime.FOVOriginal or 70
    end
end

local function toggleCrosshair(enabled)
    cleanupModule("Crosshair")
    local current = lplr:GetMouse()
    if enabled then
        moduleRuntime.CrosshairIcon = current.Icon
        current.Icon = "rbxassetid://" .. tostring(moduleSettings.Crosshair.imageId)
    else
        current.Icon = moduleRuntime.CrosshairIcon or ""
    end
end

local function toggleViewmodel(enabled)
    cleanupModule("Viewmodel")
    local function applyOffsets()
        local char = lplr.Character
        local hum = char and getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.new(moduleSettings.Viewmodel.xOffset, moduleSettings.Viewmodel.yOffset, moduleSettings.Viewmodel.zOffset)
        end
    end
    if enabled then
        applyOffsets()
        addConnection("Viewmodel", RunService.RenderStepped:Connect(applyOffsets))
    else
        local hum = lplr.Character and getHumanoid(lplr.Character)
        if hum then hum.CameraOffset = Vector3.zero end
    end
end

local function togglePickupRange(enabled)
    if enabled then moduleStates.FastPickup = true; toggleFastPickup(true) else toggleFastPickup(false); moduleStates.FastPickup = false end
end

local function toggleInterface(enabled)
    setScreenGuiEnabled(enabled)
end

local function toggleUICleanup(enabled)
    cleanupModule("UI Cleanup")
    if enabled then
        moduleRuntime.UICleanup = {FogEnd = Lighting.FogEnd, Bloom = Lighting:FindFirstChildOfClass("BloomEffect")}
        Lighting.FogEnd = 100000
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) end)
    else
        if moduleRuntime.UICleanup then Lighting.FogEnd = moduleRuntime.UICleanup.FogEnd end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
    end
end

local function toggleWinEffect(enabled)
    cleanupModule("WinEffect")
    if not enabled then return end
    addConnection("WinEffect", TextChatService.MessageReceived:Connect(function(msg)
        local text = string.lower(msg.Text or "")
        if text:find("victory") and lplr.Character and getHRP(lplr.Character) then
            local p = Instance.new("ParticleEmitter")
            p.Texture = "rbxassetid://296874871"
            p.Lifetime = NumberRange.new(1.2)
            p.Rate = 150
            p.Speed = NumberRange.new(7,12)
            p.Parent = getHRP(lplr.Character)
            Debris:AddItem(p, 2)
        end
    end))
end

local function toggleBedPlates(enabled)
    cleanupModule("BedPlates")
    if not enabled then
        for _, taggedBed in ipairs(CollectionService:GetTagged("bed")) do
            local existing = taggedBed:FindFirstChild("AetherBedPlate")
            if existing then existing:Destroy() end
        end
        return
    end

    local function decorate(bed)
        if not bed:IsA("BasePart") and not bed:IsA("Model") then return end
        if bed:FindFirstChild("AetherBedPlate") then return end
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "AetherBedPlate"
        billboard.Size = UDim2.fromOffset(130, 24)
        billboard.AlwaysOnTop = true
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
        billboard.Parent = bed

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 0.35
        label.BackgroundColor3 = Color3.new(0, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = "Bed"
        label.Parent = billboard
    end

    for _, bed in ipairs(CollectionService:GetTagged("bed")) do decorate(bed) end
    addConnection("BedPlates", CollectionService:GetInstanceAddedSignal("bed"):Connect(decorate))
end

local function toggleBreaker(enabled)
    -- Partial by design: this uses AetherCore Nuker path instead of Vape block-break controller hooks.
    toggleNuker(enabled)
end

local function toggleAutoPearl(enabled)
    cleanupModule("AutoPearl")
    if not enabled then return end
    addConnection("AutoPearl", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoPearl then return end
        local character = lplr.Character
        local humanoid = getHumanoid(character)
        local root = getHRP(character)
        if not humanoid or not root or humanoid.Health <= 0 then return end
        if humanoid.FloorMaterial == Enum.Material.Air and root.Velocity.Y < -moduleSettings.AutoPearl.fallTrigger then
            performPrimaryClick()
        end
    end))
end

local function toggleRavenTP(enabled)
    cleanupModule("RavenTP")
    if not enabled then return end
    addConnection("RavenTP", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates.RavenTP or input.KeyCode ~= Enum.KeyCode.R then return end
        local root = getHRP(lplr.Character)
        if root then
            root.CFrame = root.CFrame + Vector3.new(0, 12, 0)
        end
    end))
end

local function toggleMissileTP(enabled)
    cleanupModule("MissileTP")
    if not enabled then return end
    addConnection("MissileTP", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates.MissileTP or input.KeyCode ~= Enum.KeyCode.M then return end
        local root = getHRP(lplr.Character)
        if root then
            root.CFrame = root.CFrame + (root.CFrame.LookVector * 26)
        end
    end))
end

local function toggleArmorSwitch(enabled)
    cleanupModule("ArmorSwitch")
    if not enabled then return end
    -- Partial by design: inventory-slot swap APIs vary between BedWars versions.
    addConnection("ArmorSwitch", RunService.Heartbeat:Connect(function()
        if not moduleStates.ArmorSwitch then return end
    end))
end

local function toggleAutoBank(enabled)
    cleanupModule("AutoBank")
    if not enabled then return end
    -- Partial by design: personal chest deposit remotes are not consistently discoverable.
    addConnection("AutoBank", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoBank then return end
    end))
end

local function toggleAutoConsume(enabled)
    cleanupModule("AutoConsume")
    if not enabled then return end
    addConnection("AutoConsume", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoConsume then return end
    end))
end

local function toggleAutoHotbar(enabled)
    cleanupModule("AutoHotbar")
    if not enabled then return end
    addConnection("AutoHotbar", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoHotbar then return end
    end))
end

local function toggleFastDrop(enabled)
    cleanupModule("FastDrop")
    if not enabled then return end
    addConnection("FastDrop", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates.FastDrop or input.KeyCode ~= Enum.KeyCode.Backspace then return end
        local dropRemote = getDropItemRemote()
        if dropRemote then
            pcall(function() dropRemote:FireServer({}) end)
        end
    end))
end

local function toggleFastConsume(enabled)
    cleanupModule("FastConsume")
    if not enabled then return end
    addConnection("FastConsume", RunService.Heartbeat:Connect(function()
        if not moduleStates.FastConsume then return end
    end))
end

local function toggleStorageESP(enabled)
    cleanupModule("StorageESP")
    if not enabled then
        for _, chest in ipairs(CollectionService:GetTagged("chest")) do
            local hl = chest:FindFirstChild("AetherStorageHL")
            if hl then hl:Destroy() end
        end
        return
    end

    local function mark(obj)
        if not obj:IsA("Model") then return end
        if obj:FindFirstChild("AetherStorageHL") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "AetherStorageHL"
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(0, 255, 255)
        highlight.Adornee = obj
        highlight.Parent = obj
    end

    for _, chest in ipairs(CollectionService:GetTagged("chest")) do mark(chest) end
    addConnection("StorageESP", CollectionService:GetInstanceAddedSignal("chest"):Connect(mark))
end

local function toggleKitESP(enabled)
    cleanupModule("KitESP")
    local tags = {"lucky_block", "void_regent", "fisherman_catch"}
    if not enabled then
        for _, tag in ipairs(tags) do
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                local hl = obj:FindFirstChild("AetherKitHL")
                if hl then hl:Destroy() end
            end
        end
        return
    end

    local function mark(obj)
        if not obj:IsA("Model") then return end
        if obj:FindFirstChild("AetherKitHL") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "AetherKitHL"
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(255, 170, 0)
        highlight.Adornee = obj
        highlight.Parent = obj
    end

    for _, tag in ipairs(tags) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do mark(obj) end
        addConnection("KitESP", CollectionService:GetInstanceAddedSignal(tag):Connect(mark))
    end
end

local function toggleHealth(enabled)
    cleanupModule("Health")
    if not enabled then
        if moduleRuntime.HealthLabel then
            moduleRuntime.HealthLabel:Destroy()
            moduleRuntime.HealthLabel = nil
        end
        return
    end

    if not moduleRuntime.HealthLabel then
        local label = Instance.new("TextLabel")
        label.Name = "AetherHealthLabel"
        label.Size = UDim2.fromOffset(120, 24)
        label.Position = UDim2.new(0.5, -60, 1, -120)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3 = Color3.new(0, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Parent = screenGui
        moduleRuntime.HealthLabel = label
    end

    addConnection("Health", RunService.RenderStepped:Connect(function()
        local character = lplr.Character
        local hp = character and character:GetAttribute("Health")
        local maxHp = character and character:GetAttribute("MaxHealth")
        if moduleRuntime.HealthLabel then
            moduleRuntime.HealthLabel.Text = string.format("%d / %d", math.floor(hp or 0), math.floor(maxHp or 0))
        end
    end))
end

local function toggleHitBoxes(enabled)
    toggleReach(enabled)
end

local function toggleTriggerBot(enabled)
    toggleAutoClicker(enabled)
end

local function toggleProjectileAura(enabled)
    toggleAimbot(enabled)
end

local function toggleProjectileAimbot(enabled)
    toggleAimbot(enabled)
end

local function toggleSoundChanger(enabled)
    cleanupModule("SoundChanger")
    if not enabled then return end
    addConnection("SoundChanger", RunService.Heartbeat:Connect(function()
        if not moduleStates.SoundChanger then return end
    end))
end

local function toggleSongBeats(enabled)
    cleanupModule("Song Beats")
    if not enabled then return end
    local sound = Instance.new("Sound")
    sound.Name = "AetherSongBeats"
    sound.Volume = 0.2
    sound.Parent = Workspace
    moduleRuntime.SongBeatsSound = sound
    addConnection("Song Beats", sound.Ended:Connect(function() end))
    addConnection("Song Beats", RunService.RenderStepped:Connect(function()
        if not moduleStates["Song Beats"] and moduleRuntime.SongBeatsSound then
            moduleRuntime.SongBeatsSound:Destroy()
            moduleRuntime.SongBeatsSound = nil
        end
    end))
end

local function toggleKillEffect(enabled)
    cleanupModule("Kill Effect")
    if not enabled then return end
    addConnection("Kill Effect", TextChatService.MessageReceived:Connect(function(msg)
        if not moduleStates["Kill Effect"] then return end
        local text = string.lower(msg.Text or "")
        if text:find("final kill") then
            local effectPart = Instance.new("Part")
            effectPart.Anchored = true
            effectPart.CanCollide = false
            effectPart.Material = Enum.Material.Neon
            effectPart.Color = Color3.fromRGB(170, 120, 255)
            effectPart.Size = Vector3.new(0.6, 0.6, 0.6)
            local root = getHRP(lplr.Character)
            effectPart.Position = root and (root.Position + Vector3.new(0, 4, 0)) or Vector3.zero
            effectPart.Parent = Workspace
            Debris:AddItem(effectPart, 1)
        end
    end))
end

local function toggleReachDisplay(enabled)
    cleanupModule("Reach Display")
    if not enabled then
        if moduleRuntime.ReachDisplayLabel then
            moduleRuntime.ReachDisplayLabel:Destroy()
            moduleRuntime.ReachDisplayLabel = nil
        end
        return
    end

    local label = Instance.new("TextLabel")
    label.Name = "AetherReachDisplay"
    label.Size = UDim2.fromOffset(110, 24)
    label.Position = UDim2.new(0.5, -55, 1, -90)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundTransparency = 0.35
    label.BackgroundColor3 = Color3.new(0, 0, 0)
    label.Parent = screenGui
    moduleRuntime.ReachDisplayLabel = label

    addConnection("Reach Display", RunService.RenderStepped:Connect(function()
        local hit = mouse.Target
        local root = getHRP(lplr.Character)
        if moduleRuntime.ReachDisplayLabel then
            local distance = (hit and root) and (hit.Position - root.Position).Magnitude or 0
            moduleRuntime.ReachDisplayLabel.Text = string.format("%.2f studs", distance)
        end
    end))
end

local function toggleCleanKit(enabled)
    cleanupModule("Clean Kit")
    if enabled then
        local gui = lplr:FindFirstChildOfClass("PlayerGui")
        if gui then
            local wind = gui:FindFirstChild("WindWalkerEffect", true)
            if wind and wind:IsA("GuiObject") then
                wind.Visible = false
            end
        end
    end
end

local function toggleBedBreakEffect(enabled)
    cleanupModule("Bed Break Effect")
    if not enabled then return end
    addConnection("Bed Break Effect", TextChatService.MessageReceived:Connect(function(msg)
        if not moduleStates["Bed Break Effect"] then return end
        if string.lower(msg.Text or ""):find("bed") and string.lower(msg.Text or ""):find("broken") then
            local root = getHRP(lplr.Character)
            if root then
                local emitter = Instance.new("ParticleEmitter")
                emitter.Rate = 200
                emitter.Lifetime = NumberRange.new(0.4)
                emitter.Speed = NumberRange.new(10)
                emitter.Parent = root
                Debris:AddItem(emitter, 0.5)
            end
        end
    end))
end

local function toggleDamageIndicator(enabled)
    cleanupModule("Damage Indicator")
    if not enabled then return end
    addConnection("Damage Indicator", Workspace.DescendantAdded:Connect(function(obj)
        if not moduleStates["Damage Indicator"] then return end
        if obj:IsA("TextLabel") and string.find(string.lower(obj.Name), "damage", 1, true) then
            obj.TextColor3 = Color3.fromRGB(255, 90, 90)
            obj.TextStrokeTransparency = 0.15
        end
    end))
end
local function toggleAlias(handler)
    return function(enabled)
        if handler then
            handler(enabled)
        end
    end
end

local function toggleAntiAFK(enabled)
    if enabled then
        moduleConnections["AntiAFKPulse"] = moduleConnections["AntiAFKPulse"] or RunService.Heartbeat:Connect(function()
            local character = lplr.Character
            local humanoid = character and getHumanoid(character)
            if humanoid and humanoid.MoveDirection.Magnitude <= 0.01 then
                humanoid:Move(Vector3.new(0.001, 0, 0), true)
            end
        end)
    else
        local connection = moduleConnections["AntiAFKPulse"]
        if connection then
            connection:Disconnect()
            moduleConnections["AntiAFKPulse"] = nil
        end
    end
end

local vapePalette = {
    bg = Color3.fromRGB(18, 18, 18),
    bg2 = Color3.fromRGB(22, 22, 22),
    window = Color3.fromRGB(28, 28, 28),
    window2 = Color3.fromRGB(34, 34, 34),
    row = Color3.fromRGB(38, 38, 38),
    rowHover = Color3.fromRGB(47, 47, 47),
    rowOn = Color3.fromRGB(134, 72, 214),
    rowOn2 = Color3.fromRGB(103, 53, 174),
    accent = palette.accent or Color3.fromRGB(164, 94, 233),
    text = Color3.fromRGB(245, 245, 245),
    muted = Color3.fromRGB(175, 175, 175),
    darkText = Color3.fromRGB(125, 125, 125),
    stroke = Color3.fromRGB(52, 52, 52),
    danger = palette.danger or Color3.fromRGB(180, 65, 65)
}

local function clearChildrenExceptLayout(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function addStroke(target, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or vapePalette.stroke
    stroke.Transparency = transparency or 0.35
    stroke.Thickness = thickness or 1
    stroke.Parent = target
    return stroke
end

local function addGradient(target, colorA, colorB, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(1, colorB)
    })
    gradient.Rotation = rotation or 90
    gradient.Parent = target
    return gradient
end

local function styleVapeWindow(frame)
    frame.BackgroundColor3 = vapePalette.window
    frame.BorderSizePixel = 0
    addCorner(frame, 4)
    addStroke(frame, vapePalette.stroke, 0.25, 1)
end

local function styleVapeHeader(frame)
    frame.BackgroundColor3 = vapePalette.bg
    frame.BorderSizePixel = 0
    addCorner(frame, 4)
    addGradient(frame, Color3.fromRGB(31, 31, 31), Color3.fromRGB(18, 18, 18), 90)
end

local function setButtonState(button, active)
    button.BackgroundColor3 = active and vapePalette.rowOn or vapePalette.row
    button.TextColor3 = active and vapePalette.text or vapePalette.muted
end

local function createVapeSidebarButton(parent, label, icon, active)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = active and vapePalette.rowOn or vapePalette.row
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = string.format("  %s  %s", icon or "", label)
    button.TextColor3 = active and vapePalette.text or vapePalette.muted
    button.Font = Enum.Font.SourceSans
    button.TextSize = 18
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = parent
    addCorner(button, 3)

    button.MouseEnter:Connect(function()
        if button.BackgroundColor3 ~= vapePalette.rowOn then
            button.BackgroundColor3 = vapePalette.rowHover
        end
    end)
    button.MouseLeave:Connect(function()
        if button.BackgroundColor3 ~= vapePalette.rowOn then
            button.BackgroundColor3 = vapePalette.row
        end
    end)

    return button
end

-- Main sidebar restyle: more Vape-like, less dashboard-y.
mainPanel.Size = UDim2.new(0, 205, 0, 455)
mainPanel.Position = UDim2.new(0, 75, 0, 105)
styleVapeWindow(mainPanel)

mainTop.Size = UDim2.new(1, 0, 0, 42)
styleVapeHeader(mainTop)

mainTitle.Text = "AetherCore"
mainTitle.Font = Enum.Font.SourceSansBold
mainTitle.TextSize = 24
mainTitle.TextColor3 = vapePalette.text
mainTitle.Position = UDim2.new(0, 12, 0, 0)
mainTitle.Size = UDim2.new(1, -24, 1, 0)

local mainAccentLine = Instance.new("Frame")
mainAccentLine.Size = UDim2.new(1, 0, 0, 2)
mainAccentLine.Position = UDim2.new(0, 0, 1, -2)
mainAccentLine.BackgroundColor3 = vapePalette.accent
mainAccentLine.BorderSizePixel = 0
mainAccentLine.Parent = mainTop

mainList.Size = UDim2.new(1, -14, 1, -58)
mainList.Position = UDim2.new(0, 7, 0, 50)
mainList.BackgroundTransparency = 1
mainListLayout.Padding = UDim.new(0, 5)

-- Top bar restyle to match Vape's simple utility strip.
topBar.Size = UDim2.new(0, 370, 0, 38)
topBar.Position = UDim2.new(0, 295, 0, 105)
styleVapeWindow(topBar)

searchBox.Size = UDim2.new(1, -130, 0, 24)
searchBox.Position = UDim2.new(0, 8, 0, 7)
searchBox.BackgroundColor3 = vapePalette.row
searchBox.TextColor3 = vapePalette.text
searchBox.PlaceholderColor3 = vapePalette.darkText
searchBox.Font = Enum.Font.SourceSans
searchBox.TextSize = 16

closeButton.Size = UDim2.new(0, 112, 0, 24)
closeButton.Position = UDim2.new(1, -120, 0, 7)
closeButton.BackgroundColor3 = vapePalette.danger
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 15
closeButton.Text = "Self Destruct"

statusPanel.Size = UDim2.new(0, 275, 0, 25)
statusPanel.Position = UDim2.new(0, 75, 0, 570)
styleVapeWindow(statusPanel)
statusDiscord.Font = Enum.Font.SourceSans
statusDiscord.TextSize = 14
statusTime.Font = Enum.Font.SourceSans
statusTime.TextSize = 14

local function createCategoryColumn(categoryName, index)
    local panel = createPanel(categoryName .. "Column", UDim2.new(0, 220, 0, 520), UDim2.new(0, 295 + ((index - 1) * 228), 0, 155))
    panel.Visible = false
    styleVapeWindow(panel)

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 36)
    top.BackgroundColor3 = vapePalette.bg
    top.BorderSizePixel = 0
    top.Parent = panel
    styleVapeHeader(top)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -42, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = categoryName
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = vapePalette.text
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.Parent = top

    local countTag = Instance.new("TextLabel")
    countTag.Name = "CountTag"
    countTag.Size = UDim2.new(0, 30, 0, 20)
    countTag.Position = UDim2.new(1, -36, 0, 8)
    countTag.BackgroundColor3 = vapePalette.row
    countTag.BorderSizePixel = 0
    countTag.Text = "0"
    countTag.TextColor3 = vapePalette.muted
    countTag.Font = Enum.Font.SourceSansBold
    countTag.TextSize = 14
    countTag.Parent = top
    addCorner(countTag, 3)

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BorderSizePixel = 0
    line.BackgroundColor3 = vapePalette.accent
    line.Parent = top

    local list = Instance.new("ScrollingFrame")
    list.Name = "ModuleList"
    list.Size = UDim2.new(1, -10, 1, -46)
    list.Position = UDim2.new(0, 5, 0, 41)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = vapePalette.accent
    list.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = list

    local savedPos = loadedCategoryPositions[categoryName]
    if type(savedPos) == "table" then
        panel.Position = UDim2.new(0, tonumber(savedPos.x) or panel.Position.X.Offset, 0, tonumber(savedPos.y) or panel.Position.Y.Offset)
    end

    local cameraInstance = Workspace.CurrentCamera
    if cameraInstance then
        local viewport = cameraInstance.ViewportSize
        local maxX = math.max(10, viewport.X - panel.Size.X.Offset - 10)
        local maxY = math.max(10, viewport.Y - panel.Size.Y.Offset - 10)
        panel.Position = UDim2.new(0, math.clamp(panel.Position.X.Offset, 10, maxX), 0, math.clamp(panel.Position.Y.Offset, 10, maxY))
    end

    makeDraggable(panel, top)
    categoryPanels[categoryName] = panel
    categoryManualVisibility[categoryName] = panel.Visible
    panelFrames[categoryName] = panel
    return panel, list
end

local categoryLists = {}
for i, name in ipairs(categoryOrder) do
    local panel, list = createCategoryColumn(name, i)
    categoryLists[name] = list
end

local categoryData = {
    {name = "Combat", icon = "⚔"},
    {name = "Blatant", icon = "◆"},
    {name = "Render", icon = "◉"},
    {name = "Utility", icon = "◈"},
    {name = "World", icon = "◇"},
    {name = "Legend", icon = "★"}
}

homeTabButton = createVapeSidebarButton(mainList, "Home", "⌂", true)

for _, category in ipairs(categoryData) do
    local button = createVapeSidebarButton(mainList, category.name, category.icon, false)
    categoryToggleButtons[category.name] = button

    button.MouseButton1Click:Connect(function()
        local panel = categoryPanels[category.name]
        local newVisibility = not panel.Visible
        panel.Visible = newVisibility
        categoryManualVisibility[category.name] = newVisibility
        setButtonState(button, panel.Visible)

        if panel.Visible then
            local cameraInstance = Workspace.CurrentCamera
            if cameraInstance then
                local viewport = cameraInstance.ViewportSize
                local maxX = math.max(10, viewport.X - panel.AbsoluteSize.X - 10)
                local maxY = math.max(10, viewport.Y - panel.AbsoluteSize.Y - 10)
                local visibleCount = 0
                for _, categoryName in ipairs(categoryOrder) do
                    local categoryPanel = categoryPanels[categoryName]
                    if categoryPanel and categoryPanel.Visible and categoryPanel ~= panel then
                        visibleCount += 1
                    end
                end
                local preferredX = topBar.Position.X.Offset + topBar.Size.X.Offset + 10 + (visibleCount * (panel.Size.X.Offset + 8))
                local preferredY = mainPanel.Position.Y.Offset + 50
                panel.Position = UDim2.new(0, math.clamp(preferredX, 10, maxX), 0, math.clamp(preferredY, 10, maxY))
            end
        end

        saveClientSettings()
    end)
end

local settingsTabSeparator = Instance.new("Frame")
settingsTabSeparator.Size = UDim2.new(1, 0, 0, 10)
settingsTabSeparator.BackgroundTransparency = 1
settingsTabSeparator.Parent = mainList

settingsTabButton = createVapeSidebarButton(mainList, "Settings", "⚙", false)
scriptHubTabButton = createVapeSidebarButton(mainList, "ScriptHub", "✦", false)

local function uiCreateSlider(parent, name, min, max, default, callback, options)
    options = options or {}

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = vapePalette.muted
    label.Font = Enum.Font.SourceSans
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueButton = Instance.new("TextButton")
    valueButton.Size = UDim2.new(0.35, -4, 0, 18)
    valueButton.Position = UDim2.new(0.65, 4, 0, 0)
    valueButton.BackgroundColor3 = vapePalette.row
    valueButton.BorderSizePixel = 0
    valueButton.TextColor3 = vapePalette.text
    valueButton.Font = Enum.Font.SourceSans
    valueButton.TextSize = 14
    valueButton.Parent = frame
    addCorner(valueButton, 3)

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 7)
    slider.Position = UDim2.new(0, 0, 0, 27)
    slider.BackgroundColor3 = vapePalette.row
    slider.BorderSizePixel = 0
    slider.Parent = frame
    addCorner(slider, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = vapePalette.accent
    fill.BorderSizePixel = 0
    fill.Parent = slider
    addCorner(fill, 3)

    local dragging = false
    local range = max - min

    local function apply(v, fromTextEntry)
        local numeric = tonumber(v)
        if not numeric then return end
        local allowBeyondMax = fromTextEntry and options.allowTextInputBeyondMax
        local appliedValue = allowBeyondMax and math.max(numeric, min) or math.clamp(numeric, min, max)
        local visualValue = math.clamp(appliedValue, min, max)
        fill.Size = UDim2.new((visualValue - min) / range, 0, 1, 0)
        valueButton.Text = tostring(math.floor(appliedValue * 100) / 100)
        callback(appliedValue)
    end

    apply(default)

    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local percent = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            apply(min + (percent * range), false)
        end
    end)

    local lastClick = 0
    valueButton.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick >= 0.35 then
            lastClick = now
            return
        end
        lastClick = 0

        local box = Instance.new("TextBox")
        box.Size = valueButton.Size
        box.Position = valueButton.Position
        box.BackgroundColor3 = vapePalette.bg2
        box.BorderSizePixel = 0
        box.TextColor3 = vapePalette.text
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.ClearTextOnFocus = false
        box.Text = valueButton.Text
        box.Parent = frame
        addCorner(box, 3)
        box:CaptureFocus()
        box.FocusLost:Connect(function()
            apply(box.Text, true)
            box:Destroy()
        end)
    end)
end

local function uiCreateToggle(parent, name, default, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 28)
    button.BackgroundColor3 = default and vapePalette.rowOn or vapePalette.row
    button.BorderSizePixel = 0
    button.TextColor3 = vapePalette.text
    button.Font = Enum.Font.SourceSans
    button.TextSize = 15
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.Parent = parent
    addCorner(button, 3)

    local state = default == true
    local function refresh()
        button.BackgroundColor3 = state and vapePalette.rowOn or vapePalette.row
        button.Text = "  " .. name .. (state and "  ON" or "  OFF")
    end
    refresh()

    button.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        callback(state)
    end)
end

local function uiCreateDropdown(parent, name, options, default, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 28)
    button.BackgroundColor3 = vapePalette.row
    button.BorderSizePixel = 0
    button.TextColor3 = vapePalette.text
    button.Font = Enum.Font.SourceSans
    button.TextSize = 15
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.Parent = parent
    addCorner(button, 3)

    local selected = default
    local function refreshText()
        button.Text = string.format("  %s: %s", name, tostring(selected))
    end
    refreshText()

    button.MouseButton1Click:Connect(function()
        local idx = table.find(options, selected) or 1
        idx = (idx % #options) + 1
        selected = options[idx]
        refreshText()
        callback(selected)
    end)
end

local function uiCreateTextBox(parent, name, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 30)
    holder.BackgroundColor3 = vapePalette.row
    holder.BorderSizePixel = 0
    holder.Parent = parent
    addCorner(holder, 3)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "  " .. name
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = vapePalette.text
    label.Font = Enum.Font.SourceSans
    label.TextSize = 15
    label.Parent = holder

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.55, -6, 1, -8)
    box.Position = UDim2.new(0.45, 3, 0, 4)
    box.BackgroundColor3 = vapePalette.bg2
    box.BorderSizePixel = 0
    box.Text = tostring(default)
    box.TextColor3 = vapePalette.text
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.SourceSans
    box.TextSize = 14
    box.Parent = holder
    addCorner(box, 3)

    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
end

local function createSettingsContent(parent, moduleName)
    local defs = moduleDefinitions[moduleName] or {}
    if #defs == 0 then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 24)
        label.BackgroundTransparency = 1
        label.Text = "No configurable settings"
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = vapePalette.darkText
        label.Font = Enum.Font.SourceSans
        label.TextSize = 15
        label.Parent = parent
        return
    end

    for _, setting in ipairs(defs) do
        if setting.type == "slider" then
            uiCreateSlider(parent, setting.name, setting.min, setting.max, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end, { allowTextInputBeyondMax = setting.allowTextInputBeyondMax == true })
        elseif setting.type == "toggle" then
            uiCreateToggle(parent, setting.name, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end)
        elseif setting.type == "dropdown" then
            uiCreateDropdown(parent, setting.name, setting.options, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end)
        elseif setting.type == "textbox" then
            uiCreateTextBox(parent, setting.name, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end)
        end
    end
end

local function createModule(category, moduleName, defaultEnabled, toggleCallback)
    local list = categoryLists[category]
    if not list then return end

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -2, 0, 34)
    card.BackgroundColor3 = vapePalette.row
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = list
    addCorner(card, 3)

    local toggleArea = Instance.new("TextButton")
    toggleArea.Size = UDim2.new(1, -64, 0, 34)
    toggleArea.Position = UDim2.new(0, 0, 0, 0)
    toggleArea.BackgroundTransparency = 1
    toggleArea.AutoButtonColor = false
    toggleArea.Text = ""
    toggleArea.Parent = card

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, 0)
    accentBar.Position = UDim2.new(0, 0, 0, 0)
    accentBar.BackgroundColor3 = vapePalette.accent
    accentBar.BorderSizePixel = 0
    accentBar.Visible = false
    accentBar.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -82, 0, 34)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = moduleName
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = vapePalette.muted
    title.Font = Enum.Font.SourceSans
    title.TextSize = 18
    title.Parent = card

    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Size = UDim2.new(0, 25, 0, 24)
    settingsBtn.Position = UDim2.new(1, -58, 0, 5)
    settingsBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    settingsBtn.BackgroundTransparency = 0.1
    settingsBtn.BorderSizePixel = 0
    settingsBtn.Text = "…"
    settingsBtn.TextColor3 = vapePalette.muted
    settingsBtn.Font = Enum.Font.SourceSansBold
    settingsBtn.TextSize = 18
    settingsBtn.Parent = card
    addCorner(settingsBtn, 3)

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0, 28, 0, 24)
    keybindBtn.Position = UDim2.new(1, -30, 0, 5)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    keybindBtn.BackgroundTransparency = 0.1
    keybindBtn.BorderSizePixel = 0
    keybindBtn.TextColor3 = vapePalette.muted
    keybindBtn.Text = moduleKeybinds[moduleName] and moduleKeybinds[moduleName].Name or "-"
    keybindBtn.Font = Enum.Font.SourceSans
    keybindBtn.TextSize = 14
    keybindBtn.Parent = card
    addCorner(keybindBtn, 3)

    local settingsHolder = Instance.new("Frame")
    settingsHolder.Size = UDim2.new(1, -14, 0, 0)
    settingsHolder.Position = UDim2.new(0, 7, 0, 38)
    settingsHolder.BackgroundTransparency = 1
    settingsHolder.ClipsDescendants = true
    settingsHolder.Parent = card

    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 5)
    settingsLayout.Parent = settingsHolder

    local enabled = defaultEnabled
    if type(loadedModuleStates[moduleName]) == "boolean" then
        enabled = loadedModuleStates[moduleName]
    end
    moduleStates[moduleName] = enabled
    if moduleName == "AutoToxic" then
        autoToxicEnabled = enabled
    end

    local function updateCardVisual()
        card.BackgroundColor3 = enabled and vapePalette.rowOn2 or vapePalette.row
        title.TextColor3 = enabled and vapePalette.text or vapePalette.muted
        accentBar.Visible = enabled
    end

    local function toggleModule()
        enabled = not enabled
        if enabled then
            disableConflictingModules(moduleName)
        end
        moduleStates[moduleName] = enabled
        if moduleName == "AutoToxic" then
            autoToxicEnabled = enabled
        end
        if toggleCallback then
            safeCall(moduleName .. "Toggle", toggleCallback, enabled)
        end
        updateCardVisual()
        saveClientSettings()
    end

    toggleArea.MouseButton1Click:Connect(toggleModule)

    toggleArea.MouseEnter:Connect(function()
        if not enabled then card.BackgroundColor3 = vapePalette.rowHover end
    end)
    toggleArea.MouseLeave:Connect(function()
        if not enabled then card.BackgroundColor3 = vapePalette.row end
    end)

    settingsBtn.MouseButton1Click:Connect(function()
        settingsOpenByModule[moduleName] = not settingsOpenByModule[moduleName]
        clearChildrenExceptLayout(settingsHolder)

        if settingsOpenByModule[moduleName] then
            createSettingsContent(settingsHolder, moduleName)
            task.wait()
            local openSize = settingsLayout.AbsoluteContentSize.Y
            TweenService:Create(settingsHolder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -14, 0, openSize)
            }):Play()
            TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -2, 0, 44 + openSize)
            }):Play()
        else
            TweenService:Create(settingsHolder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -14, 0, 0)
            }):Play()
            TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -2, 0, 34)
            }):Play()
        end
    end)

    keybindBtn.MouseButton1Click:Connect(function()
        if keybindListening then return end
        keybindListening = true
        keybindBtn.Text = "..."
        local connection
        connection = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                for existingModule, existingKey in pairs(moduleKeybinds) do
                    if existingModule ~= moduleName and existingKey == key then
                        moduleKeybinds[existingModule] = nil
                        if moduleUi[existingModule] then
                            moduleUi[existingModule].setKeyText("-")
                        end
                    end
                end
                if moduleKeybinds[moduleName] == key then
                    moduleKeybinds[moduleName] = nil
                    keybindBtn.Text = "-"
                else
                    moduleKeybinds[moduleName] = key
                    keybindBtn.Text = key.Name
                end
                keybindListening = false
                if connection then connection:Disconnect() end
                saveClientSettings()
            end
        end)
    end)

    moduleUi[moduleName] = {
        setEnabled = function(state)
            enabled = state
            moduleStates[moduleName] = state
            if moduleName == "AutoToxic" then
                autoToxicEnabled = state
            end
            updateCardVisual()
        end,
        setKeyText = function(text)
            keybindBtn.Text = text == "NONE" and "-" or text
        end,
        setVisible = function(visible)
            card.Visible = visible
        end,
        category = category,
        name = moduleName
    }

    local header = categoryPanels[category] and categoryPanels[category]:FindFirstChildWhichIsA("Frame")
    local countTag = header and header:FindFirstChild("CountTag")
    if countTag then
        local count = 0
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("Frame") then count += 1 end
        end
        countTag.Text = tostring(count)
    end

    updateCardVisual()
    if enabled and toggleCallback then
        safeCall(moduleName .. "InitialToggle", toggleCallback, true)
    end
end


local function createRegisteredModule(category, name, defaultEnabled, toggleCallback, settingsDefinition)
    moduleDefinitions[name] = settingsDefinition or {}
    createModule(category, name, defaultEnabled, toggleCallback)
end

-- Added modules from 6872274481.vape and mapped to working AetherCore handlers.
createRegisteredModule("Combat", "TriggerBot", false, toggleTriggerBot, {})
createRegisteredModule("Blatant", "AntiFall", false, toggleAlias(toggleAntiVoid), {})
createRegisteredModule("Blatant", "HitBoxes", false, toggleHitBoxes, {})
createRegisteredModule("Blatant", "KeepSprint", false, toggleAlias(toggleSprint), {})
createRegisteredModule("Blatant", "Killaura", false, toggleAlias(toggleKillAura), {})
createRegisteredModule("Blatant", "NoSlowdown", false, toggleAlias(toggleSprint), {})
createRegisteredModule("Blatant", "ProjectileAimbot", false, toggleProjectileAimbot, {})
createRegisteredModule("Blatant", "ProjectileAura", false, toggleProjectileAura, {})
createRegisteredModule("Render", "Health", false, toggleHealth, {})
createRegisteredModule("Render", "KitESP", false, toggleKitESP, {})
createRegisteredModule("Render", "StorageESP", false, toggleStorageESP, {})
createRegisteredModule("Utility", "AutoBalloon", false, toggleAlias(toggleFly), {})
createRegisteredModule("Utility", "AutoKit", false, toggleAlias(toggleAutoBuy), {})
createRegisteredModule("Utility", "AutoPearl", false, toggleAutoPearl, {{type = "slider", name = "Fall Trigger", min = 10, max = 80, settingName = "fallTrigger"}})
createRegisteredModule("Utility", "AutoPlay", false, toggleAutoPlay, {})
createRegisteredModule("Utility", "AutoShoot", false, toggleAutoShoot, {})
createRegisteredModule("Utility", "MissileTP", false, toggleMissileTP, {})
createRegisteredModule("Utility", "PickupRange", false, togglePickupRange, {{type = "slider", name = "Range", min = 6, max = 30, settingName = "range"}})
createRegisteredModule("Utility", "RavenTP", false, toggleRavenTP, {})
createRegisteredModule("Utility", "ShopTierBypass", false, toggleShopTierBypass, {})
createRegisteredModule("Utility", "StaffDetector", false, toggleStaffDetector, {})
createRegisteredModule("Utility", "TrapDisabler", false, toggleTrapDisabler, {})
createRegisteredModule("World", "Anti-AFK", false, toggleAntiAFK, {})
createRegisteredModule("World", "AutoSuffocate", false, toggleAutoSuffocate, {})
createRegisteredModule("World", "AutoTool", false, toggleAlias(toggleNuker), {})
createRegisteredModule("World", "BedProtector", false, toggleAlias(toggleScaffold), {})
createRegisteredModule("World", "ChestSteal", false, toggleAlias(toggleFastPickup), {})
createRegisteredModule("World", "Schematica", false, toggleAlias(toggleScaffold), {})
createRegisteredModule("Utility", "ArmorSwitch", false, toggleArmorSwitch, {})
createRegisteredModule("Utility", "AutoBank", false, toggleAutoBank, {})
createRegisteredModule("Utility", "AutoConsume", false, toggleAutoConsume, {})
createRegisteredModule("Utility", "AutoHotbar", false, toggleAutoHotbar, {})
createRegisteredModule("Utility", "FastConsume", false, toggleFastConsume, {})
createRegisteredModule("Utility", "FastDrop", false, toggleFastDrop, {})
createRegisteredModule("Render", "BedPlates", false, toggleBedPlates, {})
createRegisteredModule("World", "Breaker", false, toggleBreaker, {})
createRegisteredModule("Render", "Bed Break Effect", false, toggleBedBreakEffect, {})
createRegisteredModule("Render", "Clean Kit", false, toggleCleanKit, {})
createRegisteredModule("Render", "Crosshair", false, toggleCrosshair, {{type = "textbox", name = "Image ID", settingName = "imageId"}})
createRegisteredModule("Render", "Damage Indicator", false, toggleDamageIndicator, {})
createRegisteredModule("Render", "FOV", false, toggleFOV, {{type = "slider", name = "Field Of View", min = 50, max = 120, settingName = "value"}})
createRegisteredModule("Render", "FPS Boost", false, toggleFPSBoost, {})
createRegisteredModule("Render", "Hit Color", false, toggleHitColor, {})
createRegisteredModule("Render", "HitFix", false, toggleAlias(toggleReach), {})
createRegisteredModule("Render", "Interface", false, toggleInterface, {})
createRegisteredModule("Render", "Kill Effect", false, toggleKillEffect, {})
createRegisteredModule("Render", "Reach Display", false, toggleReachDisplay, {})
createRegisteredModule("Render", "Song Beats", false, toggleSongBeats, {})
createRegisteredModule("Render", "SoundChanger", false, toggleSoundChanger, {})
createRegisteredModule("Render", "UI Cleanup", false, toggleUICleanup, {})
createRegisteredModule("Render", "Viewmodel", false, toggleViewmodel, {{type = "slider", name = "X Offset", min = -3, max = 3, settingName = "xOffset"}, {type = "slider", name = "Y Offset", min = -3, max = 3, settingName = "yOffset"}, {type = "slider", name = "Z Offset", min = -3, max = 3, settingName = "zOffset"}})
createRegisteredModule("Render", "WinEffect", false, toggleWinEffect, {})

createRegisteredModule("Combat", "KillAura", false, toggleKillAura, {
    {type = "toggle", name = "Face Target", settingName = "faceTarget"},
    {type = "slider", name = "FOV Radius", min = 50, max = 600, settingName = "fovRadius"},
    {type = "slider", name = "Range", min = 5, max = 20, settingName = "range"},
    {type = "slider", name = "Swing Speed", min = 1, max = 20, settingName = "swingSpeed"},
    {type = "toggle", name = "Require Sword", settingName = "requireSword"},
    {type = "toggle", name = "Click Simulation", settingName = "fallbackToClickSimulation"},
    {type = "toggle", name = "Attack Players", settingName = "attackPlayers"},
    {type = "toggle", name = "Attack NPCs", settingName = "attackNPCs"}
})
createRegisteredModule("Combat", "Reach", false, toggleReach, {
    {type = "dropdown", name = "Mode", options = {"Both", "Attribute", "Handle"}, settingName = "mode"},
    {type = "slider", name = "Hit Range", min = 6, max = 20, settingName = "hitRange"},
    {type = "slider", name = "Mine Range", min = 6, max = 20, settingName = "mineRange"},
    {type = "slider", name = "Place Range", min = 6, max = 20, settingName = "placeRange"}
})
createRegisteredModule("Combat", "AimAssist", false, toggleAimAssist, {
    {type = "slider", name = "Speed", min = 0.01, max = 0.5, settingName = "speed"},
    {type = "slider", name = "Range", min = 10, max = 50, settingName = "range"}
})
createRegisteredModule("Combat", "Aimbot", false, toggleAimbot, {
    {type = "slider", name = "FOV", min = 20, max = 450, settingName = "fov"},
    {type = "slider", name = "Smoothness", min = 0.01, max = 1, settingName = "smoothness"},
    {type = "slider", name = "Snap Strength", min = 0.1, max = 1, settingName = "snapStrength"},
    {type = "slider", name = "Prediction", min = 0, max = 2, settingName = "predictionStrength"},
    {type = "slider", name = "Max Distance", min = 60, max = 400, settingName = "maxDistance"},
    {type = "dropdown", name = "Target Part", options = {"Head", "HumanoidRootPart"}, settingName = "targetPart"},
    {type = "toggle", name = "Wall Check", settingName = "wallCheck"},
    {type = "toggle", name = "Team Check", settingName = "teamCheck"},
    {type = "toggle", name = "Target NPCs", settingName = "targetNPCs"}
})
createRegisteredModule("Combat", "AutoClicker", false, toggleAutoClicker, {
    {type = "slider", name = "CPS", min = 1, max = 20, settingName = "cps"}
})
createRegisteredModule("Combat", "Sprint", false, toggleSprint, {
    {type = "toggle", name = "Omni Sprint", settingName = "omni"}
})
createRegisteredModule("Combat", "AutoQueue", false, toggleAutoQueue, {
    {type = "slider", name = "Queue Delay", min = 0.1, max = 5, settingName = "delay"}
})
createRegisteredModule("Combat", "Velocity", false, toggleVelocity, {
    {type = "slider", name = "Horizontal %", min = 0, max = 100, settingName = "horizontalReduction"},
    {type = "slider", name = "Vertical %", min = 0, max = 100, settingName = "verticalReduction"}
})
createRegisteredModule("Combat", "NoClickDelay", false, toggleNoClickDelay, {})
createRegisteredModule("Blatant", "Speed", false, toggleSpeed, {
    {type = "slider", name = "Speed", min = 16, max = 50, settingName = "speed"}
})
createRegisteredModule("Blatant", "Step", false, toggleStep, {
    {type = "slider", name = "Max Height", min = 2, max = 14, settingName = "maxHeight"},
    {type = "slider", name = "Forward Check", min = 1.5, max = 5, settingName = "forwardCheckDistance"},
    {type = "slider", name = "Step Cooldown", min = 0.03, max = 0.25, settingName = "stepCooldown"}
})
createRegisteredModule("Blatant", "SafeWalk", false, toggleSafeWalk, {
    {type = "dropdown", name = "Mode", options = {"Normal", "TP"}, settingName = "mode"},
    {type = "slider", name = "Max Drop", min = 2, max = 10, settingName = "maxDrop"}
})
createRegisteredModule("Blatant", "HighJump", false, toggleHighJump, {
    {type = "slider", name = "Boost", min = 10, max = 180, settingName = "boost"}
})
createRegisteredModule("Blatant", "Fly", false, toggleFly, {
    {type = "slider", name = "Horizontal Speed", min = 10, max = 100, settingName = "horizontalSpeed"},
    {type = "slider", name = "Vertical Speed", min = 10, max = 100, settingName = "verticalSpeed"},
    {type = "toggle", name = "TP Down", settingName = "tpDownEnabled"},
    {type = "slider", name = "TP Interval", min = 1, max = 5, settingName = "tpDownInterval"},
    {type = "slider", name = "TP Return Delay", min = 0.05, max = 1, settingName = "tpDownReturnDelay"}
})
createRegisteredModule("Blatant", "VerticalFly", false, toggleVerticalFly, {
    {type = "slider", name = "Horizontal Speed", min = 8, max = 60, settingName = "horizontalSpeed"},
    {type = "slider", name = "Vertical Speed", min = 10, max = 120, settingName = "verticalSpeed"},
    {type = "slider", name = "Ground Offset", min = 1, max = 8, settingName = "groundOffset"},
    {type = "slider", name = "Anti Kick Sink", min = 0, max = 6, settingName = "antiKickSink"}
})
createRegisteredModule("Blatant", "LongJump", false, toggleLongJump, {
    {type = "slider", name = "Speed", min = 1, max = 37, settingName = "speed"},
    {type = "toggle", name = "Camera Direction", settingName = "cameraDirection"}
})
createRegisteredModule("Blatant", "Blink", false, toggleBlink, {
    {type = "slider", name = "Pulse Seconds", min = 0, max = 5, settingName = "pulseSeconds"}
})
createRegisteredModule("Blatant", "BedNuker", false, toggleBedNuker, {
    {type = "slider", name = "Range", min = 8, max = 40, settingName = "range"}
})
createRegisteredModule("Blatant", "NoFall", false, toggleNoFall, {
    {type = "dropdown", name = "Method", options = {"Landing", "NegateVelocity", "Teleport", "DaoExploit"}, settingName = "method"}
})
createRegisteredModule("Blatant", "Scaffold", false, toggleScaffold, {
    {type = "toggle", name = "Allow Towering", settingName = "allowTowering"},
    {type = "slider", name = "Place Ahead", min = 0, max = 2, settingName = "placeAhead"}
})
createRegisteredModule("Render", "ESP", false, toggleESP, {})
createRegisteredModule("Render", "Tracers", false, toggleTracers, {
    {type = "slider", name = "Transparency", min = 0, max = 1, settingName = "transparency"}
})
createRegisteredModule("Render", "BedESP", false, toggleBedESP, {})
createRegisteredModule("Render", "NameTags", false, toggleNameTags, {})
createRegisteredModule("Utility", "AutoToxic", false, nil, {
    {type = "toggle", name = "Final Kill Message", settingName = "enabledFinalKill"},
    {type = "textbox", name = "Final Kill Text", settingName = "finalKillMessage"},
    {type = "toggle", name = "Bed Break Message", settingName = "enabledBedBreak"},
    {type = "textbox", name = "Bed Break Text", settingName = "bedBreakMessage"},
    {type = "toggle", name = "Game Win Message", settingName = "enabledGameWin"},
    {type = "textbox", name = "Game Win Text", settingName = "gameWinMessage"},
    {type = "toggle", name = "Auto GG", settingName = "autoGG"},
    {type = "toggle", name = "Sponsor Mode", settingName = "sponsorMode"},
    {type = "textbox", name = "Custom Phrases (|)", settingName = "customPhrases"}
})
createRegisteredModule("Utility", "AutoBuy", false, toggleAutoBuy, {
    {type = "toggle", name = "Auto Sword", settingName = "sword"},
    {type = "toggle", name = "Auto Armor", settingName = "armor"},
    {type = "toggle", name = "Auto Upgrades", settingName = "upgrades"}
})
createRegisteredModule("Utility", "OpenShop", false, toggleOpenShop, {})
createRegisteredModule("Utility", "OpenTeamUpgrades", false, toggleOpenTeamUpgrades, {})
createRegisteredModule("Utility", "NoFallDamage", false, toggleNoFallDamage, {
    {type = "dropdown", name = "Method", options = {"Landing", "NegateVelocity", "Teleport", "DaoExploit"}, settingName = "method"}
})
createRegisteredModule("Utility", "AntiDeath", false, toggleAntiDeath, {
    {type = "slider", name = "HP Threshold", min = 1, max = 95, settingName = "healthThreshold", allowTextInputBeyondMax = true},
    {type = "slider", name = "Down Duration", min = 0.5, max = 4, settingName = "belowDuration"},
    {type = "slider", name = "Slow Mode", min = 0.2, max = 5, settingName = "slowMode"},
    {type = "slider", name = "Void Offset", min = 60, max = 250, settingName = "voidOffset"}
})
createRegisteredModule("Utility", "AntiHit", false, toggleAntiHit, {
    {type = "slider", name = "Slow Mode", min = 0.2, max = 5, settingName = "slowMode"},
    {type = "slider", name = "Rise Window", min = 0.08, max = 0.35, settingName = "riseWindow"},
    {type = "slider", name = "Void Offset", min = 60, max = 260, settingName = "voidOffset"},
    {type = "slider", name = "Damage Jitter", min = 0, max = 6, settingName = "antiDamageJitter"}
})
createRegisteredModule("Utility", "AntiVoid", false, toggleAntiVoid, {
    {type = "dropdown", name = "Method", options = {"Normal", "Bounce"}, settingName = "method"},
    {type = "slider", name = "Bounce Power", min = 50, max = 200, settingName = "bouncePower"}
})
createRegisteredModule("Utility", "FastPickup", false, toggleFastPickup, {
    {type = "slider", name = "Range", min = 4, max = 30, settingName = "range"}
})
createRegisteredModule("Utility", "AutoLeave", false, toggleAutoLeave, {
    {type = "toggle", name = "Staff Only", settingName = "staffOnly"},
    {type = "toggle", name = "Leave On Match End", settingName = "leaveOnMatchEnd"}
})
createRegisteredModule("Utility", "AntiCrash", false, toggleAntiCrash, {})
createRegisteredModule("Utility", "InfiniteJump", false, toggleInfiniteJump, {})
createRegisteredModule("Utility", "AutoVoidDrop", false, toggleAutoVoidDrop, {
    {type = "slider", name = "Void Trigger Offset", min = 4, max = 60, settingName = "triggerOffset"},
    {type = "slider", name = "Drop Interval", min = 0.1, max = 2, settingName = "dropInterval"}
})
createRegisteredModule("World", "FastBreak", false, toggleFastBreak, {
    {type = "slider", name = "Break Cooldown", min = 0, max = 0.3, settingName = "cooldown"},
    {type = "slider", name = "Attempts/Pulse", min = 1, max = 6, settingName = "attemptsPerPulse"}
})
createRegisteredModule("World", "Nuker", false, toggleNuker, {
    {type = "toggle", name = "Mine Beds", settingName = "mineBeds"},
    {type = "toggle", name = "Mine Iron", settingName = "mineIron"},
    {type = "toggle", name = "Mine Gold", settingName = "mineGold"},
    {type = "toggle", name = "Mine Diamond", settingName = "mineDiamond"},
    {type = "toggle", name = "Mine Emerald", settingName = "mineEmerald"},
    {type = "slider", name = "Radius", min = 5, max = 20, settingName = "mineRadius"}
})

local function refreshSearch()
    local visibleModulesByCategory = {}
    for _, ui in pairs(moduleUi) do
        local moduleVisible = filterMatches(ui.name)
        ui.setVisible(moduleVisible)
        if moduleVisible then
            visibleModulesByCategory[ui.category] = true
        end
    end

    local searching = string.lower(searchText or "") ~= ""
    local showingCategories = activeSidebarTab == "Modules"
    for categoryName, panel in pairs(categoryPanels) do
        local manuallyVisible = categoryManualVisibility[categoryName] == true
        local hasVisibleModules = visibleModulesByCategory[categoryName] == true
        panel.Visible = showingCategories and (searching and manuallyVisible and hasVisibleModules or manuallyVisible)

        local categoryButton = categoryToggleButtons[categoryName]
        if categoryButton then
            categoryButton.BackgroundColor3 = panel.Visible and palette.active or palette.panel
        end
    end
end

local function setActiveSidebarTab(tabName)
    activeSidebarTab = tabName
    homeDashboardPanel.Visible = tabName == "Home"
    settingsDashboardPanel.Visible = tabName == "Settings"
    scriptHubDashboardPanel.Visible = tabName == "ScriptHub"

    if homeTabButton then
        homeTabButton.BackgroundColor3 = tabName == "Home" and palette.active or palette.panel
    end
    if settingsTabButton then
        settingsTabButton.BackgroundColor3 = tabName == "Settings" and palette.active or palette.panel
    end
    if scriptHubTabButton then
        scriptHubTabButton.BackgroundColor3 = tabName == "ScriptHub" and palette.active or palette.panel
    end

    refreshSearch()
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = searchBox.Text or ""
    refreshSearch()
end)
homeTabButton.MouseButton1Click:Connect(function()
    setActiveSidebarTab("Home")
end)

settingsTabButton.MouseButton1Click:Connect(function()
    setActiveSidebarTab("Settings")
end)

scriptHubTabButton.MouseButton1Click:Connect(function()
    setActiveSidebarTab("ScriptHub")
end)

for _, category in ipairs(categoryData) do
    local categoryButton = categoryToggleButtons[category.name]
    if categoryButton then
        categoryButton.MouseButton1Click:Connect(function()
            activeSidebarTab = "Modules"
            homeDashboardPanel.Visible = false
            settingsDashboardPanel.Visible = false
            if homeTabButton then homeTabButton.BackgroundColor3 = palette.panel end
            if settingsTabButton then settingsTabButton.BackgroundColor3 = palette.panel end
            if scriptHubTabButton then scriptHubTabButton.BackgroundColor3 = palette.panel end
            refreshSearch()
        end)
    end
end

setActiveSidebarTab("Home")

closeButton.MouseButton1Click:Connect(function()
    if autoToxicMessageConnection then
        autoToxicMessageConnection:Disconnect()
        autoToxicMessageConnection = nil
    end
    local sharedEnvironment = sharedEnvironmentGetter and sharedEnvironmentGetter() or nil
    if sharedEnvironment and sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] then
        sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = nil
    end

    for name, enabled in pairs(moduleStates) do
        if enabled then
            moduleStates[name] = false
            if moduleHandlers[name] then
                safeCall(name .. "Disable", moduleHandlers[name], false)
            end
            if moduleUi[name] then
                moduleUi[name].setEnabled(false)
            end
        end
    end
    screenGui:Destroy()
end)

--====================================================
-- key binds
--====================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or keybindListening then return end

    if input.KeyCode == Enum.KeyCode.RightShift then
        if screenGui and screenGui.Parent then
            guiEnabled = not guiEnabled
            screenGui.Enabled = guiEnabled
        else
            warn("[AetherCore] UI is unavailable to toggle.")
        end
        return
    end

    for moduleName, key in pairs(moduleKeybinds) do
        if input.KeyCode == key then
            local enabled = not moduleStates[moduleName]
            if enabled then
                disableConflictingModules(moduleName)
            end
            moduleStates[moduleName] = enabled
            if moduleUi[moduleName] then
                moduleUi[moduleName].setEnabled(enabled)
            end
            if moduleHandlers[moduleName] then
                safeCall(moduleName .. "KeybindToggle", moduleHandlers[moduleName], enabled)
            end
            saveClientSettings()
            break
        end
    end
end)

lplr.CharacterAdded:Connect(function()
    for name, enabled in pairs(moduleStates) do
        if enabled and moduleHandlers[name] then
            safeCall(name .. "CharacterAddedToggle", moduleHandlers[name], true)
        end
    end
end)
