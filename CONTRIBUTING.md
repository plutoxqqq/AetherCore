# Contributing to AetherCore

Thanks for helping improve AetherCore. Keep contributions AetherCore-specific even when following the VapeV4-style project layout.

## Code standards

- Keep `loader.lua` minimal. It should only locate, fetch, compile, and run `main.lua`.
- Keep feature logic out of `loadstring`, `loader.lua`, `NewMainScript.lua`, and `a.txt`.
- Put shared helpers in `libraries/`, GUI implementations in `guis/`, reusable assets in `assets/`, and universal or place-specific logic in `games/`.
- Name numeric place files after the Roblox `PlaceId`, for example `games/6872274481.luau`.
- Return clear `false, "reason"` results from modules when a dependency is missing instead of failing silently.
- Use formal names, comments, and messages. Avoid slang in code and documentation.

## Adding modules

1. Add universal modules to `games/universal.luau` only when they are safe in every experience.
2. Add place-specific modules to the matching `games/<PlaceId>.luau` file.
3. Register modules through the GUI category APIs already prepared by `main.lua`.
4. Test startup flow with the public `loadstring`, `loader.lua`, and direct `NewMainScript.lua` compatibility entrypoint when possible.

## Pull requests

- Explain what changed and why.
- List manual and automated checks you ran.
- Do not commit private executor configs, runtime cache folders, or personal profiles.
