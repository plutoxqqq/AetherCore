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

function setupAutoToxic()
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

function toggleAutoToxic(enabled)
    autoToxicEnabled = enabled and true or false
end

Aether.RegisterModule({
    Name = "AutoToxic",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoToxic"] or {},
    Start = function(ctx)
        toggleAutoToxic(true)
    end,
    Stop = function(ctx)
        toggleAutoToxic(false)
    end
})
