# AetherCore – Modern BedWars Script

AetherCore is a Roblox BedWars script organised with a CatV6-style loader layout while preserving the existing AetherCore module payloads and branding.

**Loadstring:**
```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/loadstring"))()
```

Existing compatibility loadstrings that point to `AetherCoreMain/AetherCore.lua` still work because that file delegates to the new root `loadstring` entry.

## Layout

- `loadstring` is the smallest public entry file and runs `init.lua`.
- `init.lua` prepares startup options and executor cache folders, then loads `main.lua`.
- `main.lua` loads libraries, the selected GUI, universal modules, supported game modules, and `custom_modules.luau`.
- `games/bedwars/main.lua` contains the preserved unified BedWars payload.
- `games/bedwars/modules/` stores the preserved source payloads used to build the unified BedWars module set.
- `profiles/supported.json` maps BedWars GameId and PlaceIds to the right game loader.

## AetherCore Features

AetherCore keeps the existing combined BedWars module set, including the AetherCore base payload and compatibility payload modules such as VoidWalk, AntiDeath, LongJump, and many more.

## Latest Changes

```luau
AetherCore v3.1.0

[+] Reworked the repository into a CatV6-style folder layout
[+] Added loadstring -> init.lua -> main.lua loading flow
[+] Added profiles, GUI selector, shared libraries, universal loader, and game routing
[+] Preserved the existing BedWars module payload and compatibility entrypoint
```

---

Made for the Roblox scripting community.
