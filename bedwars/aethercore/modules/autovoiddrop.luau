moduleSettings["AutoVoidDrop"] = {
    triggerOffset = 18,
    dropInterval = 0.45
}

function toggleAutoVoidDrop(enabled)
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



Aether.RegisterModule({
    Name = "AutoVoidDrop",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoVoidDrop"] or {},
    Start = function(ctx)
        toggleAutoVoidDrop(true)
    end,
    Stop = function(ctx)
        toggleAutoVoidDrop(false)
    end
})
