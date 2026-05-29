function toggleAutoBuy(enabled)
    cleanupModule("AutoBuy")
    if not enabled then return end
    addConnection("AutoBuy", task.spawn(function()
        local function getInventoryItems()
            local inventoryGetter = vapeFunctionTable and vapeFunctionTable.getInventory
            if type(inventoryGetter) == "function" then
                local ok, inventory = pcall(inventoryGetter, lplr)
                if ok and type(inventory) == "table" and type(inventory.items) == "table" then
                    return inventory.items
                end
            end
            return {}
        end

        local function hasInventoryItem(itemType)
            if type(itemType) ~= "string" or itemType == "" then
                return false
            end
            for _, item in pairs(getInventoryItems()) do
                if type(item) == "table" and item.itemType == itemType and (tonumber(item.amount) or 0) > 0 then
                    return true
                end
            end
            return false
        end

        local function requestShopPurchase(itemType)
            if type(itemType) ~= "string" or itemType == "" then
                return false
            end
            local netManaged = getNetManagedFolder()
            if not netManaged then
                return false
            end
            local purchaseRemote = netManaged:FindFirstChild("BedwarsPurchaseItem")
            if not purchaseRemote then
                return false
            end
            local ok = pcall(function()
                purchaseRemote:InvokeServer({
                    shopItem = {itemType = itemType},
                    shopId = "ItemShop"
                })
            end)
            return ok
        end

        local function purchaseFirstMissing(itemTypes)
            for _, itemType in ipairs(itemTypes) do
                if not hasInventoryItem(itemType) then
                    if requestShopPurchase(itemType) then
                        return true
                    end
                end
            end
            return false
        end

        local swordOrder = {"wood_sword", "stone_sword", "iron_sword", "diamond_sword"}
        local armorOrder = {"leather_chestplate", "iron_chestplate", "diamond_chestplate"}
        local upgradeOrder = {"wood_pickaxe", "stone_pickaxe", "iron_pickaxe", "wood_axe", "stone_axe", "iron_axe"}

        while moduleStates["AutoBuy"] do
            local settings = moduleSettings["AutoBuy"] or {}
            local bought = false

            if settings.sword then
                bought = purchaseFirstMissing(swordOrder) or bought
            end
            if settings.armor then
                bought = purchaseFirstMissing(armorOrder) or bought
            end
            if settings.upgrades then
                bought = purchaseFirstMissing(upgradeOrder) or bought
            end

            task.wait(bought and 0.3 or 0.8)
        end
    end))
end


Aether.RegisterModule({
    Name = "AutoBuy",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoBuy"] or {},
    Start = function(ctx)
        toggleAutoBuy(true)
    end,
    Stop = function(ctx)
        toggleAutoBuy(false)
    end
})
