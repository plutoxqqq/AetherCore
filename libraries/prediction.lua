-- General prediction helpers used by shared and game-specific modules.
local Prediction = {}

function Prediction.Linear(position, velocity, seconds)
    return position + (velocity * seconds)
end

return Prediction
