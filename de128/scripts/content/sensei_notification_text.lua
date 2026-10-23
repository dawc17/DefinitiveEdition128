local sf2 = require("sf2")
-- Text lives in localizations/<language>.toml.
local text = {}
for _, key in ipairs({
    "ending",
    "intro",
    "more",
    "title",
}) do
    text[key] = sf2.text.get("sensei.notify." .. key)
end
return text
