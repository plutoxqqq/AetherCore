-- Legacy GUI compatibility alias.
-- No separate old GUI existed in this project, so this safely delegates to the default GUI.
return function(context)
    return context.LoadModule("guis/new.lua")
end
