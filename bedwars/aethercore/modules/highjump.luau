moduleSettings["HighJump"] = {
    boost = 40
}

function toggleHighJump(enabled)
    cleanupModule("HighJump")
    if not enabled then
        return
    end

    local char = getCharacter(lplr)
    local hum = getHumanoid(char)
    local hrp = getHRP(char)
    if not hum or not hrp then
        setModuleEnabled("HighJump", false)
        return
    end

    local boost = math.clamp(moduleSettings["HighJump"].boost or 40, 10, 180)
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, boost, hrp.AssemblyLinearVelocity.Z)
    task.delay(0.08, function()
        setModuleEnabled("HighJump", false)
    end)
end



Aether.RegisterModule({
    Name = "HighJump",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["HighJump"] or {},
    Start = function(ctx)
        toggleHighJump(true)
    end,
    Stop = function(ctx)
        toggleHighJump(false)
    end
})
