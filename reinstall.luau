-- Optional AetherCore repair helper.
-- This file is intentionally non-destructive: it only resets the local GUI choice
-- when executor file APIs are available. Add cache clearing here only with clear intent.
local guiPath = "AetherCore/profiles/gui.txt"
if type(writefile) == "function" then
    writefile(guiPath, "new")
    warn("[AetherCore] Reset GUI profile to 'new'.")
else
    warn("[AetherCore] writefile is unavailable; nothing was changed.")
end
