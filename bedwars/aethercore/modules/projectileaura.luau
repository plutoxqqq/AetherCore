moduleSettings["ProjectileAura"] = {
    range = 80,
    delay = 0.45,
    projectileKeywords = {"snowball", "fireball", "bow", "crossbow"}
}

local function getProjectileTool()
    return getHeldOrBackpackToolByKeywords((moduleSettings["ProjectileAura"] or {}).projectileKeywords or {"snowball", "fireball", "bow", "crossbow"})
end

function toggleProjectileAura(enabled)
    cleanupModule("ProjectileAura")
    if not enabled then return end
    addConnection("ProjectileAura", task.spawn(function()
        while moduleStates["ProjectileAura"] do
            local settings = moduleSettings["ProjectileAura"] or {}
            local target = getNearestEnemy(math.clamp(tonumber(settings.range) or 80, 16, 160), true)
            local tool = target and getProjectileTool() or nil
            if target and tool and equipToolIfNeeded(tool) then
                faceCharacterTarget(target)
                safeCall("ProjectileAuraActivate", function()
                    tool:Activate()
                end)
            end
            task.wait(math.max(0.1, tonumber(settings.delay) or 0.45))
        end
    end))
end

Aether.RegisterModule({
    Name = "ProjectileAura",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["ProjectileAura"] or {},
    Start = function(ctx)
        toggleProjectileAura(true)
    end,
    Stop = function(ctx)
        toggleProjectileAura(false)
    end
})
