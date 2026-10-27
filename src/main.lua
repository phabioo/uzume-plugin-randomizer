-- Entry module of the Randomizer plugin: hands presets and supported games to Uzume (fb.variants.register)
-- and shows a status card in the game detail. Uzume draws the dialogs, the variant list and the builds.
local presets = require("presets")
local games = require("games")
local card = require("card")

local fb = fb
local t = fb.i18n.t

fb.log.info(t("loaded", { version = (fb.plugin and fb.plugin.version) or "?" }))

local function preset_list()
  local list = {}
  for _, id in ipairs(presets.order) do
    list[#list + 1] = {
      id = id,
      label = t("preset_" .. id .. "_label"),
      hint = t("preset_" .. id .. "_hint"),
      settings = presets.settings[id],
    }
  end
  return list
end

local function game_list()
  local list = {}
  for _, entry in ipairs(games.games) do
    local codes = {}
    for i, c in ipairs(entry.codes) do codes[i] = c end
    list[#list + 1] = { system = entry.system, codes = codes }
  end
  return list
end

-- Once at load, also in the shell context (no game running).
local ok, err = pcall(fb.variants.register, { engine = "randomizer", presets = preset_list(), games = game_list() })
if not ok then fb.log.error(t("register_failed", { error = tostring(err) })) end

fb.events.on("fb", "detail.game", function(game)
  if type(game) ~= "table" then
    fb.ui.clear("detail")
    return
  end
  fb.ui.set("detail", card.build(t, game))
end)
