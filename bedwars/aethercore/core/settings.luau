function initSettings()
    Aether.Settings.moduleSettings = {
        KillAura = {range = 14, swingSpeed = 18},
        AutoClicker = {cps = 10},
        Sprint = {omni = true},
        Speed = {speed = 23},
        Step = {maxHeight = 6, forwardCheckDistance = 2.6},
        SafeWalk = {maxDrop = 4.5},
        HighJump = {boost = 80},
        Aimbot = {
            fov = 160,
            smoothness = 0.55,
            predictionStrength = 1,
            arrowSpeed = 185,
            gravity = (Aether.Services.Workspace and Aether.Services.Workspace.Gravity) or 196.2,
            maxDistance = 260
        },
        Reach = {hitRange = 13, mineRange = 18, placeRange = 18},
        VerticalFly = {horizontalSpeed = 28, verticalSpeed = 45, groundOffset = 3.2, hoverHeight = 3.2},
        AntiDeath = {healthThreshold = 25, belowDuration = 2, slowMode = 1.5, voidOffset = 130},
        AntiHit = {slowMode = 1, riseWindow = 0.14, voidOffset = 130, antiDamageJitter = 2.2},
        FastBreak = {cooldown = 0.21, attemptsPerPulse = 2},
        AutoVoidDrop = {triggerOffset = 18, dropInterval = 0.45},
        FastPickup = {range = 14},
        AutoLeave = {staffOnly = true, leaveOnMatchEnd = true},
        Blink = {pulseSeconds = 0},
        AutoQueue = {delay = 1},
        AutoBuy = {sword = true, armor = true, upgrades = true},
        BedNuker = {range = 20},
        AutoPlay = {random = false},
        AutoShoot = {enabled = true},
        StaffDetector = {leaveOnDetect = false},
        AutoSuffocate = {range = 18},
        FPSBoost = {removeKillEffects = true, removeVisualizer = true},
        HitColor = {r = 1, g = 0, b = 0, a = 0.4},
        FOV = {value = 80},
        Viewmodel = {xOffset = 0, yOffset = 0, zOffset = 0},
        PickupRange = {range = 16},
        AutoPearl = {fallTrigger = 28},
        Crosshair = {imageId = 9943168532}
    }
end

initSettings()
