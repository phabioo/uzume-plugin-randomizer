-- Randomizer presets: settings strings of the Universal Pokemon Randomizer FVX, keyed by settings version.
-- The strings come from the engine's own Settings#toString (see docs/presets.md); they are opaque data here.
local M = {}

-- Settings version (the 3-digit prefix of every string) of the engine release these strings were made for.
M.SETTINGS_VERSION = "428"
M.ENGINE_VERSION = "1.6.2"

-- Order is the order of the Select in the Randomize dialog. Uzume adds "Custom" itself.
M.order = { "nuzlocke", "classic", "chaos" }

M.settings = {
  nuzlocke = { ["428"] = "428wQgEBQgAAAAAAAAEAALkIAIRBBgUAAAUAAIEAAEb/wAAAAAAAADkBOQBAAgJ5AAAAOQAAgBBAAEBABAAkAAJAgAAKAEAAAi+E08AAAAA" },
  classic = { ["428"] = "428AQgEBQgAAAAAAAAEAALkBAARBAIUAAAUAAICAAEa/wAAAAAAAADkBOQBAAgJ5AAAAOQABQABAAEBAAAAAAAJAAAAKAEAAKNh4usAAAAA" },
  chaos = { ["428"] = "428gQICBnIAAAAAAAARAALkBAARHERJAQBJABEJDwIQ/wAAAAAAAADkieTBAAgJ5AAAAOQXAQABAAEBBAAAAAAJAAAAKAEAALGZzKAAAAAA" },
}

return M
