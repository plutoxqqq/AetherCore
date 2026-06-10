# AetherCore

AetherCore is a Roblox client project organized with a VapeV4-style repository layout while keeping the loader, branding, routing, and modules AetherCore-specific.

The project uses the public structure from 7GrandDadPGN's `VapeV4ForRoblox` as layout guidance for entrypoints, GUI folders, asset folders, and shared library names. Game modules and AetherCore runtime code remain project-owned.

## Public loadstring

```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/loader.lua", true))()
```

The repository also includes a `loadstring` text file for users who want a copy-paste one-liner.

## Startup flow

1. **`loadstring`**
   - Contains only the public one-line execution text.
   - Points users at `loader.lua`.
2. **`loader.lua`**
   - Minimal bootstrap file.
   - Sets `RootUrl` and `RootFolder` defaults.
   - Reads cached `main.lua` when available, otherwise fetches it from GitHub.
   - Compiles and runs `main.lua`.
3. **`main.lua`**
   - Main controller.
   - Loads shared libraries.
   - Selects a GUI from `profiles/gui.txt`.
   - Loads universal modules first.
   - Detects `game.GameId` and `game.PlaceId`.
   - Loads the matching game/place file or routed game controller.
   - Loads optional custom modules.
4. **`NewMainScript.lua`**
   - VapeV4-style compatibility entrypoint.
   - Delegates to `loader.lua`.
   - Reserved for experimental boot code or legacy support.
5. **`a.txt`**
   - Non-core helper placeholder kept for structure compatibility.

## Folder layout

```text
AetherCore/
├─ loader.lua
├─ loadstring
├─ main.lua
├─ NewMainScript.lua
├─ a.txt
├─ README.md
├─ LICENSE
├─ CONTRIBUTING.md
├─ .gitignore
├─ .gitattributes
├─ assets/
│  ├─ new/
│  ├─ old/
│  ├─ rise/
│  └─ wurst/
├─ guis/
│  ├─ new.lua
│  ├─ old.lua
│  ├─ rise.lua
│  └─ wurst.lua
├─ libraries/
│  ├─ drawing.lua
│  ├─ entity.lua
│  ├─ hash.lua
│  ├─ prediction.lua
│  └─ vm.lua
└─ games/
   ├─ universal.lua
   ├─ 6872274481.lua
   ├─ 6872265039.lua
   └─ bedwars/
      ├─ main.luau
      ├─ lobby.lua
      ├─ libraries/
      └─ modules/
```

Additional compatibility helpers such as `libraries/utility.lua`, `libraries/storage.lua`, `libraries/theme.lua`, `libraries/signal.lua`, `libraries/tween.lua`, and `libraries/target.lua` are kept because the current AetherCore runtime uses them.

## GUI selection

`profiles/gui.txt` controls the selected GUI. Valid values are:

- `new` – default AetherCore-branded compatibility GUI.
- `old` – legacy compatibility alias to the default GUI.
- `rise` – Rise-inspired theme alias to the default GUI.
- `wurst` – Wurst-inspired theme alias to the default GUI.

Unknown values fall back to `new` with a warning.

## Supported game routing

`profiles/supported.json` maps supported experiences to module paths:

```json
{
  "bedwars": {
    "gameid": 2619619496,
    "lobby": {
      "Path": "games/bedwars/lobby.lua",
      "Place": 6872265039,
      "Ids": [6872265039]
    },
    "main": {
      "Path": "games/bedwars/main.luau",
      "Place": 6872274481,
      "Ids": [6872274481, 8444591321, 8560631822]
    }
  }
}
```

If no route matches, `main.lua` falls back to `games/<PlaceId>.lua` and warns clearly if that file is unavailable.

## Games folder

`games/` is the main loader area for universal and place-specific modules.

- `games/universal.lua` runs in every supported experience.
- `games/6872274481.lua` is loaded when the current `PlaceId` is `6872274481`.
- `games/6872265039.lua` is loaded when the current `PlaceId` is `6872265039`.
- Additional place files should be named after the Roblox `PlaceId`.

## BedWars module system

The routed BedWars controller lives under `games/bedwars/` and keeps modules grouped by category:

- `Combat`
- `Blatant`
- `Render`
- `Utility`
- `World`
- `Inventory`
- `Minigames`
- `Friends`
- `Targets`
- `Profiles`
- `Legit`
- `Kits`
- `BoostFPS`

The compatibility payload remains under `games/bedwars/modules/compatibility_payload.luau` so existing AetherCore BedWars registrations continue to work while the top-level controller stays readable.

## Adding a module

1. Choose the correct universal, place-specific, or BedWars module file.
2. Register modules through the selected GUI category:

```luau
return function(context)
    local category = shared.vape.Categories.Utility
    category:CreateModule({
        Name = "Example Module",
        Function = function(enabled)
            if enabled then
                shared.vape:CreateNotification("AetherCore", "Example Module enabled", 3)
            end
        end,
        Tooltip = "Example AetherCore module."
    })
    return true
end
```

3. If you add a new file, add it to the appropriate loader or route.
4. Avoid silent failures. Return `false, "reason"` when a required dependency is unavailable.

## Adding a supported game

1. Create `games/<PlaceId>.lua` or a routed game folder such as `games/<game-name>/main.lua`.
2. Add the route to `profiles/supported.json` with `gameid`, `Place`, optional `Ids`, and `Path`.
3. Make sure the loader registers real modules or warns clearly.
4. Keep game-specific helper code under that game's folder.

## Assets

The `assets/` folder keeps the `new`, `old`, `rise`, and `wurst` asset directories for VapeV4-style path compatibility, but binary assets are intentionally not committed. AetherCore uses text-based branding fallbacks in Git so pull requests remain lightweight and can be created without binary-file restrictions.

## Current limitations

- `old`, `rise`, and `wurst` currently delegate to the default GUI with theme changes instead of shipping fully separate interfaces.
- Some runtime APIs depend on executor support.
- Optional libraries warn and continue when unavailable; required libraries stop startup with a clear error.
