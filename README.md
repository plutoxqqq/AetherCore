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
   - Loads `games/universal.luau`, then loads the `games/<PlaceId>.luau` module when one exists.
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
   ├─ universal.luau
   ├─ 6872265039.luau
   └─ 6872274481.luau
```

Additional compatibility helpers such as `libraries/utility.lua`, `libraries/storage.lua`, `libraries/theme.lua`, `libraries/signal.lua`, `libraries/tween.lua`, and `libraries/target.lua` are kept because the current AetherCore runtime uses them.

## GUI selection

`profiles/gui.txt` controls the selected GUI. Valid values are:

- `new` – default AetherCore-branded compatibility GUI.
- `old` – legacy compatibility alias to the default GUI.
- `rise` – Rise-inspired theme alias to the default GUI.
- `wurst` – Wurst-inspired theme alias to the default GUI.

Unknown values fall back to `new` with a warning.

## Supported game metadata

`profiles/supported.json` documents supported experiences and their place-specific payloads:

```json
{
  "bedwars": {
    "gameid": 2619619496,
    "lobby": {
      "Path": "games/6872265039.luau",
      "Place": 6872265039,
      "Ids": [6872265039]
    },
    "main": {
      "Path": "games/6872274481.luau",
      "Place": 6872274481,
      "Ids": [6872274481]
    }
  }
}
```

`main.lua` always loads `games/universal.luau` first. It then attempts `games/<PlaceId>.luau`; if no PlaceId file exists, it warns and continues with universal and custom modules only.

## Games folder

`games/` is the main loader area for universal and place-specific modules.

- `games/universal.luau` runs in every experience, regardless of GameId or PlaceId, and contains modules that are safe everywhere.
- Numeric files such as `games/6872265039.luau` and `games/6872274481.luau` are keyed by Roblox `PlaceId` and only run when the current `game.PlaceId` matches that number.
- `games/6872265039.luau` contains BedWars lobby-specific modules.
- `games/6872274481.luau` contains real BedWars match-specific modules.

## Place-specific module system

Place-specific files live directly under `games/` and are intentionally separate from the universal runtime. For BedWars, the lobby place and match place have independent files so lobby-only code never executes match-only modules and match-only code never executes lobby-only modules.

## Adding a module

1. Choose the correct universal or PlaceId-specific module file.
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

1. Create `games/<PlaceId>.luau` directly under `games/`.
2. Document the game in `profiles/supported.json` with `gameid`, `Place`, optional `Ids`, and `Path`.
3. Make sure the loader registers real modules or warns clearly.
4. Keep place-specific helper code inside that place file unless it is safe enough for `games/universal.luau`.

## Assets

The `assets/` folder keeps the `new`, `old`, `rise`, and `wurst` asset directories for VapeV4-style path compatibility, but binary assets are intentionally not committed. AetherCore uses text-based branding fallbacks in Git so pull requests remain lightweight and can be created without binary-file restrictions.

## Current limitations

- `old`, `rise`, and `wurst` currently delegate to the default GUI with theme changes instead of shipping fully separate interfaces.
- Some runtime APIs depend on executor support.
- Optional libraries warn and continue when unavailable; required libraries stop startup with a clear error.
