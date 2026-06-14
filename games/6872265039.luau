-- BedWars lobby entrypoint.
-- Uses the CatV6 lobby-specific BedWars loader pattern so lobby-only modules are
-- registered while match-only modules remain exclusive to games/6872274481.luau.
return function(context)
    context.BedWars = context.BedWars or {}
    context.BedWars.IsLobby = true
    context.BedWars.IsMatch = false

    local run = function(func)
        local ok, err = pcall(func)
        if not ok then
            warn("[AetherCore] BedWars lobby module failed: " .. tostring(err))
        end
    end

    local cloneref = cloneref or function(obj)
        return obj
    end

    local playersService = cloneref(game:GetService("Players"))
    local replicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
    local localPlayer = playersService.LocalPlayer
    local vape = shared and shared.vape

    if type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return false, "Vape GUI is unavailable for BedWars lobby modules"
    end

    local entityLibrary = vape.Libraries and vape.Libraries.entity
    local sessionInfo = vape.Libraries and vape.Libraries.sessioninfo
    local bedwars = {}

    local function notify(title, message, duration, notificationType)
        if type(vape.CreateNotification) == "function" then
            vape:CreateNotification(title, message, duration, notificationType)
        end
    end

    run(function()
        local knitReady, knit
        repeat
            knitReady, knit = pcall(function()
                return debug.getupvalue(require(localPlayer.PlayerScripts.TS.knit).setup, 9)
            end)
            if knitReady then
                break
            end
            task.wait()
        until knitReady

        if not debug.getupvalue(knit.Start, 1) then
            repeat
                task.wait()
            until debug.getupvalue(knit.Start, 1)
        end

        local flamework = require(replicatedStorage.rbxts_include.node_modules["@flamework"].core.out).Flamework
        local client = require(replicatedStorage.TS.remotes).default.Client

        bedwars = setmetatable({
            Client = client,
            CrateItemMeta = debug.getupvalue(flamework.resolveDependency("client/controllers/global/reward-crate/crate-controller@CrateController").onStart, 3),
            Store = require(localPlayer.PlayerScripts.TS.ui.store).ClientStore
        }, {
            __index = function(self, index)
                rawset(self, index, knit.Controllers[index])
                return rawget(self, index)
            end
        })

        if type(sessionInfo) == "table" and type(sessionInfo.AddItem) == "function" then
            sessionInfo:AddItem("Kills")
            sessionInfo:AddItem("Beds")
            sessionInfo:AddItem("Wins")
            sessionInfo:AddItem("Games")
        end

        if type(vape.Clean) == "function" then
            vape:Clean(function()
                table.clear(bedwars)
            end)
        end
    end)

    if type(vape.Modules) == "table" and type(vape.Remove) == "function" then
        for moduleName, module in pairs(vape.Modules) do
            if module.Category == "Combat" or module.Category == "Minigames" then
                vape:Remove(moduleName)
            end
        end
    end

    run(function()
        local sprint
        local oldStopSprinting

        sprint = vape.Categories.Combat:CreateModule({
            Name = "Sprint",
            Function = function(callback)
                if callback then
                    oldStopSprinting = bedwars.SprintController.stopSprinting
                    bedwars.SprintController.stopSprinting = function(...)
                        local result = oldStopSprinting(...)
                        bedwars.SprintController:startSprinting()
                        return result
                    end

                    if entityLibrary and entityLibrary.Events and entityLibrary.Events.LocalAdded then
                        sprint:Clean(entityLibrary.Events.LocalAdded:Connect(function()
                            bedwars.SprintController:stopSprinting()
                        end))
                    end

                    bedwars.SprintController:stopSprinting()
                elseif oldStopSprinting then
                    bedwars.SprintController.stopSprinting = oldStopSprinting
                    bedwars.SprintController:stopSprinting()
                end
            end,
            Tooltip = "Keeps sprinting enabled in the BedWars lobby."
        })
    end)

    run(function()
        local autoGamble

        autoGamble = vape.Categories.Minigames:CreateModule({
            Name = "AutoGamble",
            Function = function(callback)
                if callback then
                    autoGamble:Clean(bedwars.Client:GetNamespace("RewardCrate"):Get("CrateOpened"):Connect(function(data)
                        if data.openingPlayer == localPlayer then
                            local reward = data.reward or {}
                            local itemType = reward.itemType or "unknown"
                            local itemMeta = bedwars.CrateItemMeta[itemType] or {displayName = itemType}
                            notify("AutoGamble", "Won " .. tostring(itemMeta.displayName), 5)
                        end
                    end))

                    repeat
                        if not bedwars.CrateAltarController.activeCrates[1] then
                            for _, item in pairs(bedwars.Store:getState().Consumable.inventory) do
                                if type(item.consumable) == "string" and item.consumable:find("crate") then
                                    bedwars.CrateAltarController:pickCrate(item.consumable, 1)
                                    task.wait(1.2)

                                    local activeCrate = bedwars.CrateAltarController.activeCrates[1]
                                    if activeCrate and activeCrate[2] then
                                        bedwars.Client:GetNamespace("RewardCrate"):Get("OpenRewardCrate"):SendToServer({
                                            crateId = activeCrate[2].attributes.crateId
                                        })
                                    end
                                    break
                                end
                            end
                        end
                        task.wait(1)
                    until not autoGamble.Enabled
                end
            end,
            Tooltip = "Automatically opens lucky crates in the BedWars lobby."
        })
    end)

    notify("AetherCore", "BedWars lobby modules loaded.", 5)
    return true, "BedWars lobby modules loaded"
end
