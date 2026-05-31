-- TweenService helper wrapper.
local Tween = {}

function Tween.Create(instance, tweenInfo, properties)
    return game:GetService("TweenService"):Create(instance, tweenInfo, properties)
end

function Tween.Play(instance, tweenInfo, properties)
    local tween = Tween.Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

return Tween
