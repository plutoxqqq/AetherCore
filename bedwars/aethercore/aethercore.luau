-- AetherCore modular BedWars loader
-- Fetches and executes core, UI, and module files in a deterministic order.

local consoleLog = (typeof(console) == "table" and type(console.log) == "function") and console.log or print
consoleLog("Welcome to AetherCore")
consoleLog("Script is loading...")

local BASE_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/aethercore/"
local LOCAL_BASE_PATH = "bedwars/aethercore/"

Aether = {
    Services = {},
    State = {},
    Settings = {},
    UI = {},
    Modules = {},
    Helpers = {},
    Loader = {
        BaseUrl = BASE_URL,
        LocalBasePath = LOCAL_BASE_PATH,
        LoadedFiles = {}
    }
}

local coreFiles = {
    "core/services.luau",
    "core/settings.luau",
    "core/state.luau",
    "core/helpers.luau",
    "core/controllers.luau",
    "core/moduleManager.luau",
    "ui/components.luau"
}

local moduleFiles = {
    "modules/killaura.luau",
    "modules/killaura_alias.luau",
    "modules/reach.luau",
    "modules/hitfix.luau",
    "modules/speed.luau",
    "modules/sprint.luau",
    "modules/keepsprint.luau",
    "modules/noslowdown.luau",
    "modules/step.luau",
    "modules/safewalk.luau",
    "modules/highjump.luau",
    "modules/aimbot.luau",
    "modules/aimassist.luau",
    "modules/verticalfly.luau",
    "modules/fly.luau",
    "modules/longjump.luau",
    "modules/antideath.luau",
    "modules/antihit.luau",
    "modules/antifall.luau",
    "modules/antivoid.luau",
    "modules/nofall.luau",
    "modules/nofalldamage.luau",
    "modules/fastbreak.luau",
    "modules/autovoiddrop.luau",
    "modules/fastpickup.luau",
    "modules/autoleave.luau",
    "modules/blink.luau",
    "modules/autoqueue.luau",
    "modules/autobuy.luau",
    "modules/autokit.luau",
    "modules/bednuker.luau",
    "modules/nuker.luau",
    "modules/autoplay.luau",
    "modules/autoshoot.luau",
    "modules/staffdetector.luau",
    "modules/autosuffocate.luau",
    "modules/fpsboost.luau",
    "modules/hitcolor.luau",
    "modules/fov.luau",
    "modules/viewmodel.luau",
    "modules/pickuprange.luau",
    "modules/autopearl.luau",
    "modules/crosshair.luau",
    "modules/autoclicker.luau",
    "modules/velocity.luau",
    "modules/esp.luau",
    "modules/projectile_tracers.luau",
    "modules/bedesp.luau",
    "modules/nametags.luau",
    "modules/autotoxic.luau",
    "modules/trapdisabler.luau",
    "modules/shoptierbypass.luau",
    "modules/noclickdelay.luau",
    "modules/anticrash.luau",
    "modules/proximityeditor.luau",
    "modules/scaffold.luau",
    "modules/bedprotector.luau",
    "modules/schematica.luau",
    "modules/autotool.luau",
    "modules/cheststeal.luau",
    "modules/openshop.luau",
    "modules/openteamupgrades.luau",
    "modules/infinitejump.luau",
    "modules/interface.luau",
    "modules/uicleanup.luau",
    "modules/wineffect.luau",
    "modules/bedplates.luau",
    "modules/breaker.luau",
    "modules/raventp.luau",
    "modules/missiletp.luau",
    "modules/armorswitch.luau",
    "modules/autobank.luau",
    "modules/autoconsume.luau",
    "modules/autohotbar.luau",
    "modules/fastdrop.luau",
    "modules/fastconsume.luau",
    "modules/storageesp.luau",
    "modules/kitesp.luau",
    "modules/health.luau",
    "modules/hitboxes.luau",
    "modules/triggerbot.luau",
    "modules/projectileaura.luau",
    "modules/projectileaimbot.luau",
    "modules/soundchanger.luau",
    "modules/songbeats.luau",
    "modules/killeffect.luau",
    "modules/reachdisplay.luau",
    "modules/cleankit.luau",
    "modules/bedbreakeffect.luau",
    "modules/damageindicator.luau",
    "modules/antiafk.luau",
    "modules/autoballoon.luau"
}
local finalFiles = {
    "ui/window.luau"
}

local function log(message)
    print("[AetherCore] " .. tostring(message))
end

local function warnLog(message)
    warn("[AetherCore] " .. tostring(message))
end

local function fetchSource(path)
    local url = BASE_URL .. path
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if ok and type(source) == "string" and source ~= "" then
        return true, source
    end

    if type(readfile) == "function" then
        local readOk, localSource = pcall(readfile, LOCAL_BASE_PATH .. path)
        if readOk and type(localSource) == "string" and localSource ~= "" then
            warnLog("Remote download failed for " .. path .. "; using local file fallback.")
            return true, localSource
        end
    end

    return false, string.format("failed to fetch %s (%s)", url, tostring(source))
end

local function executeSource(path, source)
    if type(loadstring) ~= "function" then
        return false, "loadstring is not available in this executor"
    end

    local chunk, compileError = loadstring(source)
    if not chunk then
        return false, "compile error: " .. tostring(compileError)
    end

    local ran, runtimeError = xpcall(chunk, debug.traceback)
    if not ran then
        return false, "runtime error: " .. tostring(runtimeError)
    end

    table.insert(Aether.Loader.LoadedFiles, path)
    return true
end

local function loadFile(path, required)
    log("Loading " .. path)

    local fetched, sourceOrError = fetchSource(path)
    if not fetched then
        if required then
            error("[AetherCore] Required file failed to load: " .. path .. " - " .. tostring(sourceOrError))
        end
        warnLog("Optional file skipped: " .. path .. " - " .. tostring(sourceOrError))
        return false
    end

    local executed, executionError = executeSource(path, sourceOrError)
    if not executed then
        if required then
            error("[AetherCore] Required file failed to execute: " .. path .. " - " .. tostring(executionError))
        end
        warnLog("Optional file failed: " .. path .. " - " .. tostring(executionError))
        return false
    end

    return true
end

for _, path in ipairs(coreFiles) do
    loadFile(path, true)
end

for _, path in ipairs(moduleFiles) do
    loadFile(path, false)
end

for _, path in ipairs(finalFiles) do
    loadFile(path, true)
end

log("Loaded " .. tostring(#Aether.Loader.LoadedFiles) .. " modular files.")
