local words = require("content.text")
-- Text lives in Eclipse's localizations/eng.toml, under the game's keys. Battle fields
-- take the plain key.
local text = {}
for key, word in pairs({
    alias = "Sensei_arc",
    description = "Sensei_arc_Desc",
    locked = "Sensei_button_locked_desc",
    title = "Sensei_arc_Title",
}) do
    text[key] = words.key(word)
end
return text
