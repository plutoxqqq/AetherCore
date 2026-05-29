--====================================================
-- module manager
--====================================================

function addConnection(moduleName, connection)
    if not moduleConnections[moduleName] then
        moduleConnections[moduleName] = {}
    end
    table.insert(moduleConnections[moduleName], connection)
end

function cleanupModule(moduleName)
    if moduleConnections[moduleName] then
        for _, conn in ipairs(moduleConnections[moduleName]) do
            pcall(function()
                if typeof(conn) == "RBXScriptConnection" then
                    conn:Disconnect()
                elseif type(conn) == "thread" then
                    task.cancel(conn)
                elseif type(conn) == "function" then
                    conn()
                elseif type(conn) == "table" and type(conn.Disconnect) == "function" then
                    conn:Disconnect()
                end
            end)
        end
        moduleConnections[moduleName] = nil
    end
end

function disableConflictingModules(moduleName)
    local conflicts = moduleConflictMap[moduleName]
    if type(conflicts) ~= "table" then
        return
    end
    for _, conflictName in ipairs(conflicts) do
        if moduleStates[conflictName] then
            moduleStates[conflictName] = false
            if moduleHandlers[conflictName] then
                safeCall(conflictName .. "ConflictDisable", moduleHandlers[conflictName], false)
            end
            if moduleUi[conflictName] then
                moduleUi[conflictName].setEnabled(false)
            end
        end
    end
end

function setModuleEnabled(moduleName, enabled)
    moduleStates[moduleName] = enabled
    if moduleName == "AutoToxic" then
        autoToxicEnabled = enabled
    end
    if moduleUi[moduleName] then
        moduleUi[moduleName].setEnabled(enabled)
    end
    if moduleHandlers[moduleName] then
        safeCall(moduleName .. "ProgrammaticToggle", moduleHandlers[moduleName], enabled)
    end
end




-- New modular registry API. Module files register here; the legacy UI bridge reads
-- moduleHandlers/moduleSettings so old keybind and settings behaviour stays intact.
Aether.RegisteredModules = Aether.RegisteredModules or {}
Aether.RegisteredModuleOrder = Aether.RegisteredModuleOrder or {}

local function normalizeRegisteredName(name)
    return tostring(name or ""):lower():gsub("%s+", "")
end

function Aether.RegisterModule(moduleTable)
    assert(type(moduleTable) == "table", "moduleTable must be a table")
    assert(type(moduleTable.Name) == "string" and moduleTable.Name ~= "", "moduleTable.Name is required")

    local name = moduleTable.Name
    local key = normalizeRegisteredName(name)
    if Aether.RegisteredModules[key] then
        warn(string.format("[AetherCore] Module '%s' is already registered; replacing registration.", name))
    else
        table.insert(Aether.RegisteredModuleOrder, name)
    end

    moduleTable.Category = moduleTable.Category or "Utility"
    moduleTable.Default = moduleTable.Default == true
    moduleTable.Settings = moduleTable.Settings or moduleSettings[name] or {}
    moduleTable.Connections = moduleTable.Connections or {}

    moduleSettings[name] = moduleSettings[name] or moduleTable.Settings

    local function runModule(enabled)
        if enabled then
            disableConflictingModules(name)
            cleanupModule(name)
            if type(moduleTable.Start) == "function" then
                return moduleTable.Start(Aether)
            end
        else
            if type(moduleTable.Stop) == "function" then
                safeCall(name .. "Stop", moduleTable.Stop, Aether)
            end
            cleanupModule(name)
        end
    end

    if type(moduleTable.Start) == "function" or type(moduleTable.Stop) == "function" then
        moduleHandlers[name] = runModule
    end

    Aether.RegisteredModules[key] = moduleTable
    Aether.Modules[name] = moduleTable
    return moduleTable
end

function Aether.GetModule(name)
    return Aether.RegisteredModules[normalizeRegisteredName(name)]
end

function Aether.IsModuleEnabled(name)
    local module = Aether.GetModule(name)
    local realName = module and module.Name or name
    return moduleStates[realName] == true
end

function Aether.EnableModule(name)
    local module = Aether.GetModule(name)
    local realName = module and module.Name or name
    if moduleStates[realName] then
        return true
    end
    disableConflictingModules(realName)
    moduleStates[realName] = true
    if moduleUi[realName] then
        moduleUi[realName].setEnabled(true)
    end
    if moduleHandlers[realName] then
        safeCall(realName .. "EnableModule", moduleHandlers[realName], true)
    end
    return moduleStates[realName] == true
end

function Aether.DisableModule(name)
    local module = Aether.GetModule(name)
    local realName = module and module.Name or name
    if not moduleStates[realName] then
        cleanupModule(realName)
        return true
    end
    moduleStates[realName] = false
    if moduleUi[realName] then
        moduleUi[realName].setEnabled(false)
    end
    if moduleHandlers[realName] then
        safeCall(realName .. "DisableModule", moduleHandlers[realName], false)
    else
        cleanupModule(realName)
    end
    return moduleStates[realName] == false
end

function Aether.ToggleModule(name)
    if Aether.IsModuleEnabled(name) then
        return Aether.DisableModule(name)
    end
    return Aether.EnableModule(name)
end
