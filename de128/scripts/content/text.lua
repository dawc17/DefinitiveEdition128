local sf2 = require("sf2")

-- DE128's words are Eclipse's own English text (localizations/eng.toml in the game), under
-- the game's keys, so one file holds every line. get() gives the text handle that
-- registration fields take; key() checks the key exists and gives the plain key that battle,
-- opponent and forge fields take; read() gives the words themselves.
local text = {}

function text.get(key)
    return sf2.text.get("core:localization/" .. key)
end

function text.key(key)
    text.get(key)
    return key
end

function text.read(key)
    return sf2.text.read(text.get(key))
end

-- Items and perks must name text the mod owns: this registers the game text under the
-- mod's own id, read while loading (so edits to eng.toml show after a restart).
function text.own(id, key)
    return sf2.text.register { id = id, language = "eng", value = text.read(key) }
end

-- A game text with its {0} filled in and the original %% escapes resolved, registered under
-- this mod's own id (for texts the game keeps as one template for several ranks).
function text.fill(id, key, value)
    local filled = text.read(key):gsub("{0}", tostring(value)):gsub("%%%%", "%%")
    return sf2.text.register { id = id, language = "eng", value = filled }
end

return text
