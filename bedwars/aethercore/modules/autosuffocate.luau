function toggleAutoSuffocate(enabled)
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


Aether.RegisterModule({
    Name = "AutoSuffocate",
    Category = "World",
    Default = false,
    Settings = moduleSettings["AutoSuffocate"] or {},
    Start = function(ctx)
        toggleAutoSuffocate(true)
    end,
    Stop = function(ctx)
        toggleAutoSuffocate(false)
    end
})
