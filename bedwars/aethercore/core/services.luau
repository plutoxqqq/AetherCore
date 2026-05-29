function initServices()
    local Services = Aether.Services
    Services.Players = game:GetService("Players")
    Services.UserInputService = game:GetService("UserInputService")
    Services.TextChatService = game:GetService("TextChatService")
    Services.TweenService = game:GetService("TweenService")
    Services.HttpService = game:GetService("HttpService")
    Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
    Services.RunService = game:GetService("RunService")
    Services.Workspace = game:GetService("Workspace")
    Services.Debris = game:GetService("Debris")
    Services.VirtualUser = game:GetService("VirtualUser")
    Services.CollectionService = game:GetService("CollectionService")
    Services.Lighting = game:GetService("Lighting")
    Services.StarterGui = game:GetService("StarterGui")

    local localPlayer = Services.Players.LocalPlayer
    Services.LocalPlayer = localPlayer
    Services.Mouse = localPlayer and localPlayer:GetMouse() or nil
    Services.Camera = Services.Workspace.CurrentCamera
end

initServices()
