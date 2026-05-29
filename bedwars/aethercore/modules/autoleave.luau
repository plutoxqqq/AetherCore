function toggleAutoLeave(enabled)
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


Aether.RegisterModule({
    Name = "AutoLeave",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoLeave"] or {},
    Start = function(ctx)
        toggleAutoLeave(true)
    end,
    Stop = function(ctx)
        toggleAutoLeave(false)
    end
})
