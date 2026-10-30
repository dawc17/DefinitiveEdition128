local words = require("content.text")
-- Text lives in Eclipse's localizations/eng.toml, under the game's keys.
local text = {}
for key, word in pairs({
    ending = "Sensei_remembers2",
    intro = "Sensei_remembers0",
    more = "Sensei_remembers1",
    title = "characterSensei",
}) do
    text[key] = words.get(word)
end
return text
