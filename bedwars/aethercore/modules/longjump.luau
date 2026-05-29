moduleSettings["LongJump"] = {
    speed = 37,
    cameraDirection = false
}

function toggleLongJump(enabled)
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

Aether.RegisterModule({
    Name = "LongJump",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["LongJump"] or {},
    Start = function(ctx)
        toggleLongJump(true)
    end,
    Stop = function(ctx)
        toggleLongJump(false)
    end
})
