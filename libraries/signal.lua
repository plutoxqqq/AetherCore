-- Small signal wrapper used by loader modules that need local events.
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._event = Instance.new("BindableEvent")
    return self
end

function Signal:Connect(callback)
    return self._event.Event:Connect(callback)
end

function Signal:Fire(...)
    self._event:Fire(...)
end

function Signal:Destroy()
    if self._event then
        self._event:Destroy()
        self._event = nil
    end
end

return Signal
