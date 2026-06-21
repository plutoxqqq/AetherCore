-- AetherCore custom modules for others/main.luau
--
-- Put custom modules in this file. It is loaded automatically by others/main.luau
-- after the built-in Keybind Boost module is created.
--
-- The loader passes the GUI API as both arguments:
--   vape     -> main GUI/module API
--   context  -> { vape = vape, source = 'others/custom_modules.luau' }
--
-- Example:
-- return function(vape, context)
-- 	local example = vape.Categories.Utility:CreateModule({
-- 		Name = 'Example Module',
-- 		Tooltip = 'Example custom module. Replace this with your own module code.',
-- 		Function = function(enabled)
-- 			print('Example Module enabled:', enabled)
-- 		end
-- 	})
-- 	example:CreateToggle({Name = 'Example Setting'})
-- end
--
-- Notes:
-- - Keep this file returning a function.
-- - Paste your module creation code inside the returned function.
-- - Use the formal API name `vape`, for example:
--     local AntiFall = vape.Categories.Blatant:CreateModule({...})
-- - Define or require any helper variables your module uses before using them.
--   The Anti Fall snippet you provided depends on variables such as store,
--   getLowGround, entitylib, lplr, runService, and others, so those helpers must
--   exist in this file or be loaded by your module before Anti Fall can run.

return function(vape, context)
    AntiFall = vape.Categories.Blatant:CreateModule({
        Name = 'Anti Fall',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
                if not AntiFall.Enabled then return end
    
                local pos, debounce = getLowGround(), tick()
                if pos ~= math.huge then
                    AntiFallPart = Instance.new('Part')
                    AntiFallPart.Size = Vector3.new(10000, 1, 10000)
                    AntiFallPart.Transparency = 1 - Color.Opacity
                    AntiFallPart.Material = Enum.Material[Material.Value]
                    AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
                    AntiFallPart.CanCollide = Mode.Value == 'Collide'
                    AntiFallPart.Anchored = true
                    AntiFallPart.CanQuery = false
                    AntiFallPart.Parent = workspace
                    AntiFall:Clean(AntiFallPart)
                    AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
                        if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
                            debounce = tick() + 0.1
                            if Mode.Value == 'Normal' then
                                local top = getNearGround()
                                if top then
                                    local lastTeleport = lplr:GetAttribute('LastTeleported')
                                    local connection
                                    connection = runService.PreSimulation:Connect(function()
                                        if vape.Modules.Fly.Enabled or InfiniteFly.Enabled or vape.Modules['Long Jump'].Enabled then
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                            return
                                        end
    
                                        if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
                                            local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
                                            local root = entitylib.character.RootPart
                                            AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
                                            root.Velocity *= Vector3.new(1, 0, 1)
                                            rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
                                            rayCheck.CollisionGroup = root.CollisionGroup
    
                                            local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
                                            if ray then
                                                for _ = 1, 10 do
                                                    local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
                                                    if not getPlacedBlock(dpos) then
                                                        top = Vector3.new(top.X, pos.Y, top.Z)
                                                        break
                                                    end
                                                end
                                            end
    
                                            root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
                                            if not frictionTable.Speed then
                                                root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                            end
    
                                            if delta.Magnitude < 1 then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                            end
                                        else
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                        end
                                    end)
                                    AntiFall:Clean(connection)
                                end
                            elseif Mode.Value == 'Velocity' then
                                entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
                            end
                        end
                    end))
                end
            else
                AntiFallDirection = nil
            end
        end,
        Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
    })
    Mode = AntiFall:CreateDropdown({
        Name = 'Move Mode',
        List = {'Normal', 'Collide', 'Velocity'},
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.CanCollide = val == 'Collide'
            end
        end,
    Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
    })
    local materials = {'ForceField'}
    for _, v in Enum.Material:GetEnumItems() do
        if v.Name ~= 'ForceField' then
            table.insert(materials, v.Name)
        end
    end
    Material = AntiFall:CreateDropdown({
        Name = 'Material',
        List = materials,
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.Material = Enum.Material[val]
            end
        end
    })
    Color = AntiFall:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.5,
        Function = function(h, s, v, o)
            if AntiFallPart then
                AntiFallPart.Color = Color3.fromHSV(h, s, v)
                AntiFallPart.Transparency = 1 - o
            end
        end
    })
end)
end
