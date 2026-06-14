-- Module Assist: in-client help chatbot for AetherCore modules.
local ModuleAssist = {}

local COMMON_WORDS = {
    auto = true, aura = true, assist = true, esp = true, aim = true, bed = true,
    player = true, kit = true, utility = true, render = true, combat = true,
    speed = true, fly = true, scaffold = true, chest = true, steal = true,
    fast = true, no = true, anti = true, better = true, custom = true
}

local TOPIC_TEMPLATES = {
    {Pattern = "killaura", Text = "automatically attacks nearby valid targets when enabled"},
    {Pattern = "aura", Text = "automates repeated actions around nearby targets or objects"},
    {Pattern = "aim", Text = "helps line up your camera or projectile direction toward a selected target"},
    {Pattern = "assist", Text = "adds helper behaviour for a specific task while leaving control with you"},
    {Pattern = "esp", Text = "draws visual information so important players, objects, or objectives are easier to see"},
    {Pattern = "tracer", Text = "draws lines or indicators toward selected targets"},
    {Pattern = "speed", Text = "adjusts movement behaviour to make travelling faster"},
    {Pattern = "fly", Text = "adds flight-style movement controls"},
    {Pattern = "scaffold", Text = "helps place blocks under or around you while moving"},
    {Pattern = "bed", Text = "focuses on BedWars bed awareness, protection, or breaking support"},
    {Pattern = "chest", Text = "works with nearby chests and inventory storage"},
    {Pattern = "steal", Text = "moves useful items from accessible containers into your inventory"},
    {Pattern = "buy", Text = "automates shop purchases based on the configured item list"},
    {Pattern = "consume", Text = "uses consumable items when its configured conditions are met"},
    {Pattern = "hotbar", Text = "organises or selects hotbar slots based on your settings"},
    {Pattern = "staff", Text = "watches player joins and alerts or reacts when configured staff criteria match"},
    {Pattern = "anti", Text = "prevents or reduces the specific effect named by the module"},
    {Pattern = "velocity", Text = "changes how knockback or movement velocity is handled"},
    {Pattern = "target", Text = "selects or manages players used by combat and utility features"},
    {Pattern = "friend", Text = "stores friendly players so other modules can ignore or recolour them"},
    {Pattern = "profile", Text = "manages saved settings profiles"}
}

local MODULE_ALIAS_OVERRIDES = {
    projectileaura = {"pa", "projectile aura", "projectile aimbot", "projectile aim bot", "proj aura", "projectile arua", "projectile auro"},
    projectileaimbot = {"aimbot", "paimbot", "projectile aimbot", "projectile aim bot", "proj aimbot", "projectile aim", "projectile aimboot"},
    killaura = {"ka", "kill aura", "aura", "killaura", "kill arua"},
    autoclicker = {"ac", "auto clicker", "clicker", "auto cliker"},
    aimassist = {"aa", "aim assist", "aim helper", "aim assit"},
    bowassist = {"ba", "bow assist", "bow aimbot", "bow assit"},
    bedesp = {"bed esp", "beds", "bed visuals"},
    itemesp = {"item esp", "items", "item visuals"},
    cheststeal = {"cs", "chest steal", "stealer", "cheststeel"},
    autobuy = {"ab", "auto buy", "shop bot", "autobuy"},
    scaffold = {"scaf", "scaffold", "block place", "scafold"},
    speed = {"speed", "spd", "movement speed"},
    fly = {"fly", "flight"},
    velocity = {"velo", "velocity", "knockback", "kb"},
    staffdetector = {"staff detector", "staff detect", "staff alert", "staffdetector"}
}

local function normalise(text)
    return tostring(text or ""):lower():gsub("[^%w%s]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function compact(text)
    return normalise(text):gsub("%s+", "")
end

local function readableName(name)
    local spaced = tostring(name or ""):gsub("([a-z])([A-Z])", "%1 %2"):gsub("([A-Z])([A-Z][a-z])", "%1 %2")
    return normalise(spaced)
end

local function cleanSentence(text)
    text = tostring(text or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text ~= "" and not text:match("[%.%!%?]$") then
        text = text .. "."
    end
    return text
end

local function splitNameWords(name)
    local readable = readableName(name)
    local words = {}
    for word in readable:gmatch("%S+") do
        table.insert(words, word)
    end
    if #words == 0 then
        table.insert(words, tostring(name or "module"))
    end
    return words
end

local function titlePhrase(words)
    local filtered = {}
    for _, word in ipairs(words) do
        if not COMMON_WORDS[word] then
            table.insert(filtered, word)
        end
    end
    if #filtered == 0 then
        filtered = words
    end
    return table.concat(filtered, " ")
end

local function uniqueAliases(aliases)
    local output, seen = {}, {}
    for _, alias in ipairs(aliases or {}) do
        local cleaned = normalise(alias)
        if cleaned ~= "" and not seen[cleaned] then
            seen[cleaned] = true
            table.insert(output, cleaned)
        end
    end
    return output
end

local function moduleAliases(record)
    local name = tostring(record and record.Name or "")
    local readable = readableName(name)
    local compactName = compact(name)
    local words = splitNameWords(name)
    local aliases = {name, readable, compactName}
    local initials = ""
    for _, word in ipairs(words) do
        if #word > 0 then
            initials = initials .. word:sub(1, 1)
        end
    end
    if #initials > 1 then
        table.insert(aliases, initials)
    end
    if #words > 1 then
        table.insert(aliases, table.concat(words, " "))
        table.insert(aliases, words[#words])
    end
    local override = MODULE_ALIAS_OVERRIDES[compactName]
    if override then
        for _, alias in ipairs(override) do
            table.insert(aliases, alias)
        end
    end
    return uniqueAliases(aliases)
end

local function aliasSummary(record)
    local aliases = moduleAliases(record)
    local shown = {}
    for _, alias in ipairs(aliases) do
        if alias ~= compact(record.Name) and alias ~= readableName(record.Name) then
            table.insert(shown, alias)
        end
        if #shown >= 4 then break end
    end
    if #shown == 0 then
        return nil
    end
    return "Aliases I understand for this module include: " .. table.concat(shown, ", ") .. "."
end

local function hasOption(options, pattern)
    pattern = tostring(pattern or ""):lower()
    for _, option in ipairs(options or {}) do
        if tostring(option):lower():find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local function settingSummary(options)
    local details = {}
    if hasOption(options, "range") then table.insert(details, "range") end
    if hasOption(options, "delay") then table.insert(details, "timing") end
    if hasOption(options, "mode") then table.insert(details, "mode") end
    if hasOption(options, "target") then table.insert(details, "targeting") end
    if hasOption(options, "color") then table.insert(details, "visual colour") end
    if hasOption(options, "health") then table.insert(details, "health threshold") end
    if #details == 0 then
        return nil
    end
    return "Its settings let you tune " .. table.concat(details, ", ") .. " behaviour."
end

local function levenshtein(a, b)
    a, b = compact(a), compact(b)
    if a == b then return 0 end
    if a == "" then return #b end
    if b == "" then return #a end
    local previous = {}
    for j = 0, #b do previous[j] = j end
    for i = 1, #a do
        local current = {[0] = i}
        local ac = a:sub(i, i)
        for j = 1, #b do
            local cost = ac == b:sub(j, j) and 0 or 1
            current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous = current
    end
    return previous[#b]
end

local function similarity(a, b)
    a, b = compact(a), compact(b)
    if a == "" or b == "" then return 0 end
    if a == b then return 1 end
    if a:find(b, 1, true) or b:find(a, 1, true) then return 0.92 end
    return 1 - (levenshtein(a, b) / math.max(#a, #b))
end

local function collectOptions(module)
    local names = {}
    if type(module) == "table" and type(module.Options) == "table" then
        for name in pairs(module.Options) do
            table.insert(names, tostring(name))
        end
    end
    table.sort(names)
    return names
end

local function categoryPurpose(category)
    local purposes = {
        Combat = "combat interaction and target engagement",
        Blatant = "high-impact movement or gameplay automation",
        Render = "visual overlays and interface feedback",
        Utility = "quality-of-life automation and support tools",
        World = "world, block, and objective interaction",
        Inventory = "inventory, hotbar, shop, and item management",
        Minigames = "mode-specific minigame assistance",
        Kits = "kit-specific abilities and automation",
        Legit = "low-profile visual or convenience features",
        BoostFPS = "performance and visual simplification",
        Friends = "friend list management",
        Targets = "target list management",
        Profiles = "profile management"
    }
    return purposes[category] or "AetherCore module assistance"
end

local function inferPurpose(name, category)
    local lowered = compact(name)
    for _, item in ipairs(TOPIC_TEMPLATES) do
        if lowered:find(item.Pattern, 1, true) then
            return item.Text
        end
    end
    local words = {}
    for word in normalise(name):gmatch("%S+") do
        if not COMMON_WORDS[word] then table.insert(words, word) end
    end
    if #words > 0 then
        return "helps with " .. table.concat(words, " ") .. " using " .. categoryPurpose(category)
    end
    return "belongs to " .. categoryPurpose(category)
end

function ModuleAssist.Install(context)
    if type(shared) ~= "table" or type(shared.vape) ~= "table" or type(shared.vape.Categories) ~= "table" then
        return false, "GUI is not ready"
    end

    local vape = shared.vape
    local state = context.State or {}
    local assistant = {LastMatch = nil, History = {}}

    local function mergeRecord(recordsByName, record)
        if type(record) ~= "table" or not record.Name or record.Name == "Unknown" then
            return
        end
        local key = tostring(record.Name)
        local existing = recordsByName[key]
        if existing then
            existing.Tooltip = existing.Tooltip or record.Tooltip
            existing.Description = existing.Description or record.Description
            existing.Category = existing.Category ~= "Unknown" and existing.Category or record.Category
            return
        end
        recordsByName[key] = record
    end

    local function moduleRecords()
        local recordsByName = {}
        for _, record in ipairs(state.RegisteredModules or {}) do
            mergeRecord(recordsByName, record)
        end
        if type(vape.Modules) == "table" then
            for name, module in pairs(vape.Modules) do
                if type(name) == "string" then
                    mergeRecord(recordsByName, {
                        Name = name,
                        Category = type(module) == "table" and tostring(module.Category or module.Type or "Unknown") or "Unknown",
                        Tooltip = type(module) == "table" and type(module.Tooltip) == "string" and module.Tooltip or nil,
                        Description = type(module) == "table" and type(module.Description) == "string" and module.Description or nil
                    })
                end
            end
        end
        local records = {}
        for _, record in pairs(recordsByName) do
            table.insert(records, record)
        end
        table.sort(records, function(a, b)
            return tostring(a.Name):lower() < tostring(b.Name):lower()
        end)
        return records
    end

    local function findModule(query)
        local cleaned = normalise(query)
        if cleaned == "" and assistant.LastMatch then return assistant.LastMatch, 1 end
        local best, score, matchedAlias = nil, 0, nil
        for _, record in ipairs(moduleRecords()) do
            for _, alias in ipairs(moduleAliases(record)) do
                if cleaned == alias or compact(cleaned) == compact(alias) then
                    return record, 1, alias
                end
                if #cleaned > 2 and #alias > 2 then
                    local aliasScore = similarity(cleaned, alias)
                    if aliasScore > score then
                        best, score, matchedAlias = record, aliasScore, alias
                    end
                end
            end
            local candidateScore = math.max(
                similarity(cleaned, record.Name),
                similarity(cleaned, readableName(record.Name)),
                similarity(cleaned, (record.Category or "") .. " " .. record.Name)
            )
            if candidateScore > score then
                best, score, matchedAlias = record, candidateScore, nil
            end
        end
        if score >= 0.46 then return best, score, matchedAlias end
        if assistant.LastMatch and (cleaned:find("it", 1, true) or cleaned:find("that", 1, true) or cleaned:find("settings", 1, true) or cleaned:find("example", 1, true) or cleaned:find("how", 1, true)) then
            return assistant.LastMatch, 1, nil
        end
        return nil, score, nil
    end

    local function listAllModules()
        local byCategory, total = {}, 0
        for _, record in ipairs(moduleRecords()) do
            total = total + 1
            local category = tostring(record.Category or "Unknown")
            byCategory[category] = byCategory[category] or {}
            table.insert(byCategory[category], tostring(record.Name))
        end
        local categories = {}
        for category in pairs(byCategory) do table.insert(categories, category) end
        table.sort(categories)
        local parts = {string.format("I can explain every loaded module. %d modules are currently registered.", total)}
        for _, category in ipairs(categories) do
            table.insert(parts, category .. ": " .. table.concat(byCategory[category], ", "))
        end
        return table.concat(parts, " | ")
    end

    local function moduleExplanation(record, liveModule, options)
        local words = splitNameWords(record.Name)
        local subject = titlePhrase(words)
        local loweredName = compact(record.Name)
        local written = cleanSentence(record.Tooltip or record.Description or (type(liveModule) == "table" and (liveModule.Tooltip or liveModule.Description)) or "")
        local personalized = {}

        if written ~= "" then
            table.insert(personalized, written)
        end

        if loweredName:sub(1, 4) == "auto" then
            table.insert(personalized, cleanSentence("Personalized to " .. record.Name .. ": it automatically handles " .. subject .. " instead of making you perform that task manually"))
        elseif loweredName:sub(1, 4) == "anti" then
            table.insert(personalized, cleanSentence("Personalized to " .. record.Name .. ": it prevents, reduces, or counters " .. subject .. " effects"))
        elseif loweredName:sub(1, 2) == "no" then
            table.insert(personalized, cleanSentence("Personalized to " .. record.Name .. ": it disables or removes the " .. subject .. " behaviour named by the module"))
        elseif loweredName:sub(1, 4) == "fast" then
            table.insert(personalized, cleanSentence("Personalized to " .. record.Name .. ": it speeds up " .. subject .. " actions"))
        elseif loweredName:find("esp", 1, true) then
            table.insert(personalized, cleanSentence("Personalized to " .. record.Name .. ": it displays visual information for " .. subject .. " so you can locate it faster"))
        elseif loweredName:find("tp", 1, true) or loweredName:find("teleport", 1, true) then
            table.insert(personalized, cleanSentence("Personalized to " .. record.Name .. ": it focuses on teleport-style movement connected to " .. subject))
        else
            table.insert(personalized, cleanSentence("Personalized to " .. record.Name .. ": it " .. inferPurpose(record.Name, record.Category)))
        end

        table.insert(personalized, cleanSentence("It is registered under " .. tostring(record.Category or "General") .. ", which is used for " .. categoryPurpose(record.Category)))
        local settingsText = settingSummary(options)
        if settingsText then
            table.insert(personalized, settingsText)
        end
        return table.concat(personalized, " ")
    end

    local function moduleExample(record, options)
        local action = "enable " .. tostring(record.Name)
        local checks = {}
        if hasOption(options, "range") then table.insert(checks, "set the range only as high as you need") end
        if hasOption(options, "delay") then table.insert(checks, "adjust the delay so it does not fire too often") end
        if hasOption(options, "mode") then table.insert(checks, "choose the mode that matches your play style") end
        if hasOption(options, "target") then table.insert(checks, "confirm the target filters before using it") end
        if #checks == 0 then
            table.insert(checks, "leave its defaults on first, then change one setting at a time")
        end
        return "Example for " .. tostring(record.Name) .. ": " .. action .. ", " .. table.concat(checks, ", ") .. ", and test that single module before combining it with others."
    end

    function assistant.Ask(question)
        question = tostring(question or "")
        local lowered = normalise(question)
        if lowered == "" then
            return "Ask about any loaded module by name, for example: 'What does Killaura do?', 'give an example for AutoBuy', or 'list every module'."
        end
        if lowered:find("list", 1, true) or lowered:find("every module", 1, true) or lowered:find("all modules", 1, true) then
            return listAllModules()
        end
        local match, score, matchedAlias = findModule(question)
        if not match then
            return "I could not confidently match that to a loaded module. Check the spelling or ask with the exact module name."
        end
        assistant.LastMatch = match
        local liveModule = type(vape.Modules) == "table" and vape.Modules[match.Name] or nil
        local options = collectOptions(liveModule)
        local lines = {
            string.format("%s (%s): %s", match.Name, match.Category or "General", moduleExplanation(match, liveModule, options)),
            string.format("Matched your question to '%s'%s%s.", match.Name, matchedAlias and (" through alias '" .. matchedAlias .. "'") or "", score < 0.9 and " (typo corrected)" or "")
        }
        local aliasesText = aliasSummary(match)
        if aliasesText then
            table.insert(lines, aliasesText)
        end
        if #options > 0 then
            local shown = {}
            for i = 1, math.min(#options, 6) do shown[i] = options[i] end
            table.insert(lines, "Important settings: " .. table.concat(shown, ", ") .. (#options > 6 and ", and more." or "."))
        end
        if lowered:find("example") or lowered:find("how") then
            table.insert(lines, moduleExample(match, options))
        end
        local answer = table.concat(lines, " ")
        table.insert(assistant.History, {Question = question, Answer = answer, Module = match.Name})
        return answer
    end

    shared.AetherCoreModuleAssist = assistant

    local category = vape.Categories.ModuleAssist or vape.Categories["Module Assist"]
    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        category = vape.Categories.Utility
    end
    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        return false, "Module Assist category is unavailable"
    end

    local module = category:CreateModule({
        Name = "Module Assistant",
        Tooltip = "Ask accurate questions about loaded AetherCore modules, including typo-tolerant follow-ups.",
        Function = function() end
    })

    if type(module) == "table" then
        local input
        if type(module.CreateTextBox) == "function" then
            input = module:CreateTextBox({
                Name = "Question",
                Placeholder = "Ask what a module does...",
                Function = function(value)
                    assistant.PendingQuestion = tostring(value or "")
                end
            })
        end
        if type(module.CreateButton) == "function" then
            module:CreateButton({
                Name = "Ask Module Assist",
                Function = function()
                    local question = assistant.PendingQuestion or (type(input) == "table" and input.Value) or ""
                    local answer = assistant.Ask(question)
                    if type(vape.CreateNotification) == "function" then
                        vape:CreateNotification("Module Assist", answer, 10)
                    else
                        warn("[Module Assist] " .. answer)
                    end
                end
            })
        end
    end

    return true
end

return ModuleAssist
