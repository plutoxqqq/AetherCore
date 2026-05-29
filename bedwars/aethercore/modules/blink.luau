function toggleBlink(enabled)
    cleanupModule("Blink")
    if not enabled then return end
    if type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function" or type(newcclosure) ~= "function" or type(getnamecallmethod) ~= "function" then
        warn("[AetherCore] Blink requires metatable hook executor functions that are not available.")
        return
    end

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


Aether.RegisterModule({
    Name = "Blink",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["Blink"] or {},
    Start = function(ctx)
        toggleBlink(true)
    end,
    Stop = function(ctx)
        toggleBlink(false)
    end
})
