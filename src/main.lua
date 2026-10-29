-- Entry module of the Randomizer plugin: hands presets and supported games to Uzume (uz.variants.register)
-- and shows a status card in the game detail. Uzume draws the dialogs, the variant list and the builds.
local presets = require("presets")
local games = require("games")
local card = require("card")

local uz = uz
local t = uz.i18n.t

uz.log.info(t("loaded", { version = (uz.plugin and uz.plugin.version) or "?" }))

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
local ok, err = pcall(uz.variants.register, { engine = "randomizer", presets = preset_list(), games = game_list() })
if not ok then uz.log.error(t("register_failed", { error = tostring(err) })) end

-- Host event source: "uz" since Uzume 0.22; older apps only know "fb".
local host = rawget(_ENV, "uz") ~= nil and "uz" or "fb"

-- Variants and engine state for the card. Both calls are optional (older apps, shell context without a game):
-- a missing function or a failed call leaves that part out of the card.
local function card_info(game)
  local info = {}
  local v = uz.variants
  if type(v.engine) == "function" then
    local ok, e = pcall(v.engine)
    if ok and type(e) == "table" then info.engine = e end
  end
  -- The list needs the game id from detail.game (Uzume 22); without it (older apps) the list is left out.
  if type(v.list) == "function" and game.id ~= nil then
    local ok, l = pcall(v.list, game.id)
    if ok and type(l) == "table" then info.variants = l end
  end
  return info
end

local current

local function show()
  if current then uz.ui.set("detail", card.build(t, current, card_info(current))) end
end

uz.events.on(host, "detail.game", function(game)
  if type(game) ~= "table" then
    current = nil
    uz.ui.clear("detail")
    return
  end
  current = game
  show()
end)

-- A build changed state: refresh the card (the event carries no game data we use).
uz.events.on(host, "variants.state", function() pcall(show) end)
