-- The small status card in the game detail ("detail" slot). Text and chips only; never shows what was randomized.
local games = require("games")

local M = {}

--- Builds the tree for a detail.game payload ({ system, code, sha256, title }).
function M.build(t, game)
  local supported = games.supported(game.system, game.code)
  local title = type(game.title) == "string" and game.title ~= "" and game.title or nil
  local kids = {
    { type = "row", gap = 8, align = "center", children = {
      { type = "badge", id = "status", text = supported and t("supported") or t("not_supported"),
        tone = supported and "ok" or "neutral" },
    } },
  }
  if supported then
    kids[#kids + 1] = { type = "text", id = "line", text = title and t("supported_line", { title = title }) or t("slot_note"), style = "body" }
    if title then kids[#kids + 1] = { type = "text", id = "slot", text = t("slot_note"), style = "meta" } end
  else
    kids[#kids + 1] = { type = "text", id = "line", style = "body",
      text = title and t("unsupported_line", { title = title }) or t("unsupported_generic") }
  end
  return { type = "section", id = "randomizer", title = t("title"), children = kids }
end

return M
