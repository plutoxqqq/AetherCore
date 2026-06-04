-- Compatibility shim for callers that still reference the split payload path.
return function(context)
    return context.LoadGameModule('games/bedwars/main.luau')
end
