moduleSettings["FastConsume"] = {
    multiplier = 40
}

local function findClickHoldController()
    if moduleRuntime.FastConsumeClickHold then return moduleRuntime.FastConsumeClickHold end
    if type(getgc) ~= "function" then return nil end
    for _, value in ipairs(getgc(true)) do
        if type(value) == "table" and type(rawget(value, "startClick")) == "function" and type(rawget(value, "showProgress")) == "function" then
            moduleRuntime.FastConsumeClickHold = value
            return value
        end
    end
    return nil
end

function toggleFastConsume(enabled)
    if enabled then
        cleanupModule("FastConsume")
    end
    local clickHold = findClickHoldController()
    if not clickHold then return end
    if enabled then
        if not moduleRuntime.FastConsumeOriginalStartClick then
            moduleRuntime.FastConsumeOriginalStartClick = clickHold.startClick
            moduleRuntime.FastConsumeOriginalShowProgress = clickHold.showProgress
        end
        clickHold.startClick = function(self)
            self.startedClickTime = tick()
            local handle = self.showProgress and self:showProgress() or nil
            local clickTime = self.startedClickTime
            task.defer(function()
                local multiplier = math.clamp(tonumber((moduleSettings["FastConsume"] or {}).multiplier) or 40, 0, 100)
                task.wait((tonumber(self.durationSeconds) or 1) * (multiplier / 100))
                if handle == self.handle and clickTime == self.startedClickTime and self.closeOnComplete then
                    if type(self.hideProgress) == "function" then self:hideProgress() end
                    if type(self.onComplete) == "function" then self.onComplete() end
                    if type(self.onPartialComplete) == "function" then self.onPartialComplete(1) end
                    self.startedClickTime = -1
                end
            end)
        end
    elseif moduleRuntime.FastConsumeOriginalStartClick then
        clickHold.startClick = moduleRuntime.FastConsumeOriginalStartClick
        if moduleRuntime.FastConsumeOriginalShowProgress then
            clickHold.showProgress = moduleRuntime.FastConsumeOriginalShowProgress
        end
        moduleRuntime.FastConsumeOriginalStartClick = nil
        moduleRuntime.FastConsumeOriginalShowProgress = nil
    end
end

Aether.RegisterModule({
    Name = "FastConsume",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["FastConsume"] or {},
    Start = function(ctx)
        toggleFastConsume(true)
    end,
    Stop = function(ctx)
        toggleFastConsume(false)
    end
})
