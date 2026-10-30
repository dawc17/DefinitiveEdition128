local words = require("content.text")
-- Text lives in Eclipse's localizations/eng.toml, under the game's keys.
local text = {}
for _, key in ipairs({
    "OK",
    "Sensei_defeat1",
    "Sensei_defeat2",
    "Sensei_defeat3",
    "Sensei_defeat4",
    "Sensei_defeat5",
    "characterSensei",
}) do
    text[key] = words.get(key)
end
return text
