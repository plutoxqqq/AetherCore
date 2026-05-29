moduleSettings["AutoToxic"] = {
    finalKillMessage = "ez final",
    bedBreakMessage = "bed gone lol",
    gameWinMessage = "gg ez",
    enabledFinalKill = true,
    enabledBedBreak = true,
    enabledGameWin = true,
    enabledKill = true,
    autoGG = true,
    sponsorMode = false,
    useCustomPhrases = true,
    randomizeMessages = true,
    includeTargetName = false,
    messageCooldown = 1.5,
    customPhrases = "outplayed|too easy|nt|sit|folded"
}

local autoToxicDefaults = {
    final = {"AetherCore defeats another!", "Smoked by AetherCore", "Losing in a game?", "Beaten by pure skill"},
    bed = {"There goes your bed!", "AetherCore takes another bed!", "+1 bed break"},
    win = {"AetherCore on top!", "Yall rubbish", "Better luck next time!", "Too bad..."},
    kill = {"EZ", "So bad", "AetherCore defeats another!", "Smoked by AetherCore"}
}

local autoToxicPatterns = {
    final = {"final kill", "final killed", "eliminated"},
    bed = {"bed", "destroyed", "broken", "break"},
    win = {"victory", "you win", "won the game"},
    kill = {"killed", "knocked", "voided", "slain"}
}

local function splitAutoToxicPhrases(text)
    local phrases = {}
    for phrase in string.gmatch(tostring(text or ""), "([^|]+)") do
        phrase = phrase:gsub("^%s+", ""):gsub("%s+$", "")
        if phrase ~= "" then
            table.insert(phrases, phrase)
        end
    end
    return phrases
end

local function autoToxicContains(text, words)
    for _, word in words do
        if text:find(word, 1, true) then
            return true
        end
    end
    return false
end

local function getAutoToxicSpeaker(message)
    local source = message and message.TextSource
    if source and source.UserId then
        return Players:GetPlayerByUserId(source.UserId)
    end
    return nil
end

local function getAutoToxicTarget(text)
    for _, plr in Players:GetPlayers() do
        if plr ~= lplr then
            local name = plr.Name:lower()
            local display = plr.DisplayName and plr.DisplayName:lower() or ""
            if text:find(name, 1, true) or (display ~= "" and text:find(display, 1, true)) then
                return plr
            end
        end
    end
    return nil
end

local function buildAutoToxicMessage(kind, target)
    local settings = moduleSettings["AutoToxic"] or {}
    local messages = autoToxicDefaults[kind] or autoToxicDefaults.kill

    if kind == "final" and settings.finalKillMessage ~= "" then
        messages = {settings.finalKillMessage}
    elseif kind == "bed" and settings.bedBreakMessage ~= "" then
        messages = {settings.bedBreakMessage}
    elseif kind == "win" and settings.gameWinMessage ~= "" then
        messages = {settings.gameWinMessage}
    end

    if settings.useCustomPhrases and (kind == "kill" or kind == "final") then
        local custom = splitAutoToxicPhrases(settings.customPhrases)
        if #custom > 0 then
            messages = custom
        end
    end

    local message = messages[1]
    if settings.randomizeMessages and #messages > 1 then
        message = messages[math.random(1, #messages)]
    end

    if kind == "win" and settings.autoGG and not tostring(message):lower():find("gg", 1, true) then
        message = "gg " .. message
    end

    if settings.includeTargetName and target then
        message = message .. " " .. target.Name
    end

    if settings.sponsorMode then
        message = message .. " | AetherCore"
    end

    return message
end

local function sendAutoToxicMessage(kind, target)
    local settings = moduleSettings["AutoToxic"] or {}
    if not autoToxicEnabled then return end
    if kind == "final" and not settings.enabledFinalKill then return end
    if kind == "bed" and not settings.enabledBedBreak then return end
    if kind == "win" and not settings.enabledGameWin then return end
    if kind == "kill" and not settings.enabledKill then return end

    local now = tick()
    local cooldown = math.clamp(tonumber(settings.messageCooldown) or 1.5, 0.5, 8)
    if now - (settings.lastMessageTime or 0) < cooldown then return end
    settings.lastMessageTime = now

    local message = buildAutoToxicMessage(kind, target)
    if type(sayInChat) == "function" then
        sayInChat(message)
    elseif Aether and Aether.Helpers and type(Aether.Helpers.sayInChat) == "function" then
        Aether.Helpers.sayInChat(message)
    end
end

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
        pcall(function()
            autoToxicMessageConnection:Disconnect()
        end)
        autoToxicMessageConnection = nil
    end

    local function handleMessage(message)
        if not autoToxicEnabled then return end
        if not message or not message.Text then return end

        local speaker = getAutoToxicSpeaker(message)
        if speaker == lplr then return end

        local text = message.Text:lower()
        local myName = lplr.Name:lower()
        local myDisplay = lplr.DisplayName and lplr.DisplayName:lower() or ""
        local mentionsMe = text:find(myName, 1, true) or (myDisplay ~= "" and text:find(myDisplay, 1, true))
        local target = getAutoToxicTarget(text)

        if mentionsMe and autoToxicContains(text, autoToxicPatterns.final) then
            sendAutoToxicMessage("final", speaker)
        elseif mentionsMe and autoToxicContains(text, autoToxicPatterns.kill) then
            sendAutoToxicMessage("kill", speaker)
        elseif autoToxicContains(text, autoToxicPatterns.bed) and (mentionsMe or text:find("your", 1, true)) then
            sendAutoToxicMessage("bed", target or speaker)
        elseif autoToxicContains(text, autoToxicPatterns.win) then
            sendAutoToxicMessage("win", nil)
        end
    end

    if TextChatService and TextChatService.MessageReceived then
        autoToxicMessageConnection = TextChatService.MessageReceived:Connect(handleMessage)
        if sharedEnvironment then
            sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = autoToxicMessageConnection
        end
    end
end
setupAutoToxic()

function toggleAutoToxic(enabled)
    autoToxicEnabled = enabled and true or false
    Aether.State.autoToxicEnabled = autoToxicEnabled
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
    end,
})
