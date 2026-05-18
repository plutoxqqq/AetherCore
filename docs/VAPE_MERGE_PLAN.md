## Planned AetherCore + Vape module merge map

### Combat
- KillAura: replace with Vape implementation while keeping AetherCore UI/settings hooks.
- AutoClicker: integrate Vape placement-aware clicking logic.
- Velocity: keep percent-based horizontal/vertical control.
- NoClickDelay: add as standalone module.
- Sprint: add/improve with state-safe toggling.

### Blatant
- Speed: keep AetherCore movement core; add Vape auto-jump pathing.
- Fly (Balloons): add balloon purchase/inflate/deflate safety flow.
- Scaffold: add expand/hand-check/auto-wool/tower features.
- FastPickup: add with configurable range.
- Blink: add packet buffering/release control.

### Utility
- AutoToxic: merge final-kill + winstreak + custom phrases + autoGG + win messages.
- AntiVoid: merge robust part-based recovery path.
- NoFall: integrate requestSelfDamage bypass disable flow.
- AutoLeave: staff detection + match-end leave.
- AntiCrash: LightningStrike protection.

### Render
- BedESP: add bed discovery + render overlay.
- NameTags: add health gradient, distance, and held/armor indicators.

### Core internals
- Integrate Vape getfunctions() resolution table into AetherCore controller resolver.
- Prefer AetherCore remotes/controllers where modern equivalents exist.
- Preserve conflict handling, save/load settings, and keep anti-detection modules untouched.
