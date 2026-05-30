# AetherCore – Modern BedWars Exploiting

AetherCore is a new Roblox BedWars script. It features instant execution, lots of features, dedicated updates, and sleek UI

**Loadstring:**
```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/AetherCoreMain/AetherCore.lua"))()
```


## AetherCore Payload

AetherCore now uses one unified BedWars payload instead of the old custom module tree. The public loadstring is unchanged, but it loads `bedwars/aethercore.luau`, which combines:

- `bedwars/aerov4.luau`
- `bedwars/catvape.luau`

## Plan for AetherCore
 AetherCore is now maintained as a single combined payload to reduce loader complexity and avoid split-module inconsistencies.

## Latest Changes

```luau
AetherCore v3.0.0

[+] Rebuilt the loader around one combined payload
[+] Switched execution to the AetherCore base payload with the CatVape payload included
[+] Removed the old custom module loading flow from the public entrypoint
[+] Kept the existing public loadstring unchanged

Join our Discord server for the latest updates, announcements, and changes

Sat, 30 May, 2026
```

---

Made for the Roblox exploiting community <3
