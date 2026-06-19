-- AetherCore compatibility alias.
-- CatV6 does not ship a Wurst GUI; use the CatV6 new GUI implementation.
return loadstring(readfile('AetherCore/guis/new.lua'), 'AetherCore/guis/new.lua')(...)
