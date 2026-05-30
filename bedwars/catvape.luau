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

    task.spawn(function()
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local function launchProjectile(item, pos, proj, speed, dir)
        if not (item and pos) then return end

        pos = pos - dir * 0.1
        local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))

        switchItem(item.tool, 0)
        task.wait(0.1)

        if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
            local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
            shoot = shoot and shoot[math.random(1, #shoot)] or nil
            if shoot then
                bedwars.SoundManager:playSound(shoot)
            end
        end
    end

    local LongJumpMethods = {
        cannon = function(_, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            bedwars.placeBlock(rounded, 'cannon', false)

            task.delay(0, function()
                local block, blockpos = getPlacedBlock(rounded)
                if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
                    local breaktype = bedwars.ItemMeta[block.Name].block.breakType
                    local tool = store.tools[breaktype]
                    if tool then
                        switchItem(tool.tool)
                    end

                    bedwars.Client:Get(remotes.CannonAim):SendToServer({
                        cannonBlockPos = blockpos,
                        lookVector = dir
                    })

                    local broken = 0.1
                    if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
                        broken = 0.4
                        bedwars.breakBlock(block, true, true)
                    end

                    task.delay(broken, function()
                        for _ = 1, 3 do
                            local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
                            if call then
                                bedwars.breakBlock(block, true, true)
                                JumpSpeed = 5.25 * Value.Value
                                JumpTick = tick() + 2.3
                                Direction = Vector3.new(dir.X, 0, dir.Z).Unit
                                break
                            end
                            task.wait(0.1)
                        end
                    end)
                end
            end)
        end,

        catrewrite = function(_, _, dir)
            addConnection("LongJump", vapeEvents.CatPounce.Event:Connect(function()
                JumpSpeed = 4 * Value.Value
                JumpTick = tick() + 2.5
                Direction = Vector3.new(dir.X, 0, dir.Z).Unit
                entitylib.character.RootPart.Velocity = Vector3.zero
            end))

            if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
                repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not moduleStates["LongJump"]
            end

            if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and moduleStates["LongJump"] then
                bedwars.AbilityController:useAbility('CAT_POUNCE')
            end
        end,

        fireball = function(item, pos, dir)
            launchProjectile(item, pos, 'fireball', 60, dir)
        end,

        grappling_hook = function(item, pos, dir)
            launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
        end,

        jade_hammer = function(item, _, dir)
            if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
                repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not moduleStates["LongJump"]
            end

            if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and moduleStates["LongJump"] then
                bedwars.AbilityController:useAbility(item.itemType..'_jump')
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
                Direction = Vector3.new(dir.X, 0, dir.Z).Unit
            end
        end,

        tnt = function(item, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
            bedwars.placeBlock(rounded, item.itemType, false)
        end,

        wood_dao = function(item, pos, dir)
            if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
                repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not moduleStates["LongJump"]
            end

            if moduleStates["LongJump"] then
                bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                switchItem(item.tool, 0.1)
                replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
                    direction = dir,
                    origin = pos,
                    weapon = item.itemType
                })
                JumpSpeed = 4.5 * Value.Value
                JumpTick = tick() + 2.4
                Direction = Vector3.new(dir.X, 0, dir.Z).Unit
            end
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
        return Vector3.new(source.CFrame.LookVector.X, 0, source.CFrame.LookVector.Z).Unit
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

    -- CatVape style initial trigger
    if store.hand and LongJumpMethods[store.hand.tool.Name] then
        task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, getLookVector())
    else
        triggerMethodFromInventory()
    end

    addConnection("LongJump", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates["LongJump"] then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.F then
            triggerMethodFromInventory()
        end
    end))

    -- CatVape enhanced connections
    addConnection("LongJump", vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
        if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
            local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
                vertical = 0,
                horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
            }).Magnitude * 1.1

            if knockbackBoost >= JumpSpeed then
                local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
                if not pos then return end
                local vec = (entitylib.character.RootPart.Position - pos)
                JumpSpeed = knockbackBoost
                JumpTick = tick() + 2.5
                Direction = Vector3.new(vec.X, 0, vec.Z).Unit
            end
        end
    end))

    addConnection("LongJump", vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
        if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
            local vec = entitylib.character.RootPart.CFrame.LookVector
            JumpSpeed = 2.5 * Value.Value
            JumpTick = tick() + 2.5
            Direction = Vector3.new(vec.X, 0, vec.Z).Unit
        end
    end))

    addConnection("LongJump", RunService.PreSimulation:Connect(function(dt)
        if not moduleStates["LongJump"] then return end
        local currentChar = getCharacter(lplr)
        local root = getHRP(currentChar)
        local currentHum = getHumanoid(currentChar)
        if not (root and currentHum) or not isnetworkowner(root) then
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
