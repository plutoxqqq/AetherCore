-- BedWars lobby entrypoint.
-- BedWars can keep users in the lobby for long periods before teleporting into a
-- match. Load the same resilient BedWars module bootstrap here so the GUI never
-- opens empty when the script is executed from the lobby.
return function(context)
    context.BedWars = context.BedWars or {}
    context.BedWars.IsLobby = true
    context.BedWars.IsMatch = false

    local ok, result = context.LoadGameModule("games/6872274481.luau")
    if ok then
        context.BedWars.LobbyLoadedMatchBootstrap = true
        if type(shared) == "table" and type(shared.vape) == "table" and type(shared.vape.CreateNotification) == "function" then
            pcall(function()
                shared.vape:CreateNotification("AetherCore", "BedWars modules loaded from the lobby. Match-only features will finish when BedWars services are available.", 5)
            end)
        end
        return true, result
    end

    if type(shared) == "table" and type(shared.vape) == "table" and type(shared.vape.CreateNotification) == "function" then
        pcall(function()
            shared.vape:CreateNotification("AetherCore", "BedWars lobby loaded, but module bootstrap failed: " .. tostring(result), 8)
        end)
    end

    return false, result
end
