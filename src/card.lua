-- The small status card in the game detail ("detail" slot). Text and chips only; never shows what was randomized.
local games = require("games")

local M = {}

local MAX_ROWS = 5
local STATES = { not_built = "neutral", building = "info", ready = "ok", needs_rebuild = "warning", failed = "danger" }

local function short(v, max)
  v = tostring(v):gsub("%c", " ")
  if utf8.len(v) and utf8.len(v) > max then v = v:sub(1, (utf8.offset(v, max + 1) or (max + 1)) - 1) end
  return v
end

--- Engine line and variant list. `info` = { engine = { offered, version, on_pc } | nil, variants = { ... } | nil };
--- a field that is nil (older app, call failed) is left out. Only names, states and the engine version are shown:
--- never seeds, settings, presets or anything that was randomized.
local function info_children(t, info)
  local kids = {}
  local e = info.engine
  if type(e) == "table" then
    local line
    if not e.offered then
      line = t("engine_not_offered")
    elseif e.on_pc then
      line = t("engine_ready", { version = short(e.version or "?", 40) })
    else
      line = t("engine_download", { version = short(e.version or "?", 40) })
    end
    kids[#kids + 1] = { type = "text", id = "engine", text = line, style = "meta" }
  end
  local vs = info.variants
  if type(vs) == "table" then
    if #vs == 0 then
      kids[#kids + 1] = { type = "text", id = "variants_none", text = t("variants_none"), style = "meta" }
    else
      local rows = {}
      for i, v in ipairs(vs) do
        if i > MAX_ROWS then break end
        if type(v) == "table" then
          local state = STATES[v.state] and v.state or "not_built"
          rows[#rows + 1] = { id = "v" .. i, title = short(v.name or "?", 60), meta = t("state_" .. state), tone = STATES[state] }
        end
      end
      kids[#kids + 1] = { type = "text", text = t("variants_title"), style = "eyebrow" }
      kids[#kids + 1] = { type = "list", id = "variants", rows = rows }
      if #vs > MAX_ROWS then
        kids[#kids + 1] = { type = "text", id = "variants_more", text = t("variants_more", { n = #vs - MAX_ROWS }), style = "meta" }
      end
    end
  end
  return kids
end

--- Builds the tree for a detail.game payload ({ system, code, sha256, title }); `info` is optional.
function M.build(t, game, info)
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
    for _, k in ipairs(info_children(t, info or {})) do kids[#kids + 1] = k end
  else
    kids[#kids + 1] = { type = "text", id = "line", style = "body",
      text = title and t("unsupported_line", { title = title }) or t("unsupported_generic") }
  end
  return { type = "section", id = "randomizer", title = t("title"), children = kids }
end

return M
