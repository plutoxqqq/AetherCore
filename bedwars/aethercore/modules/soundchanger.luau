moduleSettings["SoundChanger"] = {
    sounds = {}
}

local function findSoundManager()
    if moduleRuntime.SoundChangerManager then return moduleRuntime.SoundChangerManager end
    if type(getgc) ~= "function" then return nil end
    for _, value in ipairs(getgc(true)) do
        if type(value) == "table" and type(rawget(value, "playSound")) == "function" then
            moduleRuntime.SoundChangerManager = value
            return value
        end
    end
    return nil
end

local function getSoundReplacement(id)
    local configured = (moduleSettings["SoundChanger"] or {}).sounds or {}
    local replacement = configured[id] or configured[tostring(id)]
    if type(replacement) == "string" and replacement ~= "" then
        return replacement:find("rbxasset", 1, true) and replacement or ("rbxassetid://" .. replacement:gsub("%D", ""))
    end
    return nil
end

function toggleSoundChanger(enabled)
    if enabled then
        cleanupModule("SoundChanger")
    end
    local manager = findSoundManager()
    if not manager then return end
    if enabled then
        if not moduleRuntime.SoundChangerOriginalPlaySound then
            moduleRuntime.SoundChangerOriginalPlaySound = manager.playSound
        end
        manager.playSound = function(self, id, ...)
            return moduleRuntime.SoundChangerOriginalPlaySound(self, getSoundReplacement(id) or id, ...)
        end
    elseif moduleRuntime.SoundChangerOriginalPlaySound then
        manager.playSound = moduleRuntime.SoundChangerOriginalPlaySound
        moduleRuntime.SoundChangerOriginalPlaySound = nil
    end
end

Aether.RegisterModule({
    Name = "SoundChanger",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["SoundChanger"] or {},
    Start = function(ctx)
        toggleSoundChanger(true)
    end,
    Stop = function(ctx)
        toggleSoundChanger(false)
    end
})
