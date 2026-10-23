local sf2 = require("sf2")
-- One archived Dialog Type="Regular" card through the native story dialog:
-- title, portrait (optionally mirrored), one line and the single Right button.
-- on_complete runs once when the player presses the button (or Back, unless
-- ignore_back); on_cancel runs once if scene/profile teardown closes it first.
local function definition(card, text, portrait)
    assert(text[card.title] and text[card.text] and text[card.button or "OK"], "Sensei dialog text missing")
    return {
        title = text[card.title], portrait = portrait, mirrored = card.mirrored == true,
        lines = { { text = text[card.text] } }, button = text[card.button or "OK"],
        ignore_back = card.ignore_back == true,
    }
end
local function open(card, text, portrait, on_complete, on_cancel)
    return sf2.story.play_sequence {
        steps = { { dialog = definition(card, text, portrait) } },
        on_complete = on_complete, on_cancel = on_cancel,
    }
end
return { open = open, definition = definition }
