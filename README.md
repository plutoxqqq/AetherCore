# AetherCore

AetherCore is a Roblox BedWars client organized around a VapeV4-style loader flow while keeping AetherCore branding, paths, compatibility entrypoints, and project-owned module structure.

## Public loadstring

```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/loadstring"))()
```

Legacy bootstrap URLs that point at `AetherCoreMain/AetherCore.lua` still work. That file delegates to the root `loadstring` entry.

## Startup flow

1. **`loadstring`**
   - Sets `RootUrl` and `RootFolder` only.
   - Checks `AetherCore/init.lua` first, then a legacy local `init.lua`, then GitHub raw.
   - Executes `init.lua`.
2. **`init.lua`**
   - Creates all required cache folders under `AetherCore/`.
   - Uses `profiles/version.txt` as a cache invalidation marker.
   - Refreshes the manifest into `AetherCore/<path>` when the remote version changes.
   - Loads `main.lua` and passes a startup context.
   - Does not contain feature logic.
3. **`main.lua`**
   - Waits for the Roblox game to load.
   - Installs executor fallbacks.
   - Loads required libraries (`utility`, `storage`, `theme`) and optional libraries (`signal`, `tween`, `entity`, `drawing`, `prediction`, `target`).
   - Reads `profiles/gui.txt` and loads `guis/new.lua`, `guis/old.lua`, or `guis/rise.lua`.
   - Loads universal modules before game modules.
   - Reads `profiles/supported.json` and routes by `game.GameId` / `game.PlaceId`.
   - Loads `custom_modules.luau` if present.
   - Tracks module registrations with name, category, status, and source file.
   - Saves profile data and supports `context.Reload()` / `context.Uninject()`.

## Folder layout

```text
AetherCore/
├─ loadstring
├─ init.lua
├─ main.lua
├─ games/
│  ├─ universal.lua
│  └─ bedwars/
│     ├─ main.luau
│     ├─ lobby.lua
│     ├─ modules/
│     ├─ libraries/
│     └─ profiles/
├─ guis/
│  ├─ new.lua
│  ├─ old.lua
│  └─ rise.lua
├─ libraries/
│  ├─ utility.lua
│  ├─ storage.lua
│  ├─ theme.lua
│  ├─ signal.lua
│  ├─ tween.lua
│  ├─ entity.lua
│  ├─ prediction.lua
│  ├─ target.lua
│  └─ drawing.lua
├─ profiles/
│  ├─ gui.txt
│  ├─ supported.json
│  ├─ default.txt
│  └─ premade/
├─ assets/
│  ├─ new/
│  ├─ old/
│  ├─ rise/
│  └─ shared/
└─ AetherCoreMain/
   └─ AetherCore.lua
```

## GUI selection

`profiles/gui.txt` controls the selected GUI. Valid values are:

- `new` – default AetherCore-branded compatibility GUI.
- `old` – compatibility alias to the default GUI.
- `rise` – theme variant alias to the default GUI.

If the value is unknown, AetherCore warns and falls back to `new`.

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

If no route matches, `main.lua` tries `games/<PlaceId>.lua` and warns clearly if that fallback is unavailable.

## BedWars module system

`games/bedwars/main.luau` is the full direct BedWars payload entry. Its preamble loads logical module groups from `games/bedwars/modules/` before the preserved compatibility payload registers feature modules:

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

The full AetherCore BedWars payload lives in `games/bedwars/main.luau` for compatibility with existing direct game-loader expectations. `games/bedwars/modules/compatibility_payload.luau` is only a shim for older internal callers, while the top of `main.luau` loads the logical group files before the preserved payload registers its feature modules.

## LionV5 reference compatibility

AetherCore now keeps the large BedWars payload in `games/bedwars/main.luau` and adds safe LionV5 reference compatibility registrations for module names that were missing from the AetherCore payload. Directly importing the whole LionV5 reference would reintroduce broken and unsafe external request code, so AetherCore only ports safe implementations and clear bridges for the current module set.

## Adding a module

1. Choose the correct group in `games/bedwars/modules/`.
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

3. If you add a new file, add it to `games/bedwars/libraries/loader.lua` or the relevant game loader.
4. Avoid silent failures. Return `false, "reason"` when a required dependency is unavailable.

## Adding a supported game

1. Create a game loader under `games/<game-name>/main.lua` or `main.luau`.
2. Add the route to `profiles/supported.json` with `gameid`, `Place`, optional `Ids`, and `Path`.
3. Make sure the loader registers at least one real module or warns clearly.
4. Add any game-specific libraries under `games/<game-name>/libraries/`.

## Adding a GUI

1. Create `guis/<name>.lua`.
2. Return either a GUI table or a function that returns one.
3. The GUI table must expose:
   - `Load(context)`
   - `Finalize(context)`
4. Add `<name>` to the valid GUI list in `main.lua` and document it here.
5. Keep visible branding as AetherCore.

## Profiles and cache

- Runtime profiles are saved under `AetherCore/profiles/<GameId>_<PlaceId>.json`.
- `profiles/default.txt` supplies default profile data.
- `profiles/premade/` is reserved for premade profiles.
- Legacy `default.json` configs are migrated when found.
- Cached source files are read from `AetherCore/<path>` before remote fetches.

## Current limitations

- `old` and `rise` currently alias the default GUI instead of shipping fully separate interfaces.
- Some runtime APIs depend on executor support; optional libraries warn and continue when unavailable.
- The large BedWars compatibility payload intentionally remains in `games/bedwars/main.luau`; the split files are lightweight group loaders and safe compatibility bridges.
