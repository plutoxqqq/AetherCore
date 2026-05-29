function toggleShopTierBypass(enabled)
    cleanupModule("ShopTierBypass")
    local state = rawget(_G, "AetherCoreShopTierBypassState") or {tiered = {}, nextTier = {}}
    _G.AetherCoreShopTierBypassState = state
    local shopItems = (((vapeFunctionTable or {}).ClientStore or {}).Shop and ((vapeFunctionTable or {}).ClientStore).Shop.ShopItems)
    if not shopItems then return end
    if enabled then
        for _, item in pairs(shopItems) do
            state.tiered[item] = item.tiered
            state.nextTier[item] = item.nextTier
            item.tiered = nil
            item.nextTier = nil
        end
    else
        for item, value in pairs(state.tiered) do item.tiered = value end
        for item, value in pairs(state.nextTier) do item.nextTier = value end
        state.tiered = {}
        state.nextTier = {}
    end
end

Aether.RegisterModule({
    Name = "ShopTierBypass",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["ShopTierBypass"] or {},
    Start = function(ctx)
        toggleShopTierBypass(true)
    end,
    Stop = function(ctx)
        toggleShopTierBypass(false)
    end
})
