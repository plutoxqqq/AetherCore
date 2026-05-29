function toggleStaffDetector(enabled)
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


Aether.RegisterModule({
    Name = "StaffDetector",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["StaffDetector"] or {},
    Start = function(ctx)
        toggleStaffDetector(true)
    end,
    Stop = function(ctx)
        toggleStaffDetector(false)
    end
})
