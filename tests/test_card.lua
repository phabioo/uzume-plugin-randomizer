local t = require("t")
local mock = require("uz_mock")
local games = require("games")

local function texts(tree, out)
  out = out or {}
  if tree.text then out[#out + 1] = tree.text end
  for _, c in ipairs(tree.children or {}) do texts(c, out) end
  return out
end

local function joined(tree) return table.concat(texts(tree), " | ") end

t.case("supported game: chip and slot note", function()
  local m = mock.load_bundle()
  m.fire("detail.game", { system = "nds", code = "IPKE", sha256 = "00", title = "Coral Saga: Ember" })
  local tree = m.trees.detail
  t.ok(tree, "no tree")
  local s = joined(tree)
  t.ok(s:find("Supported", 1, true) and not s:find("Not supported", 1, true), s)
  t.ok(s:find("Each variant plays in its own slot. Main is not touched.", 1, true), s)
  t.eq(tree.title, "Randomizer")
end)

t.case("unsupported game: chip and the can't-be-randomized line", function()
  local m = mock.load_bundle()
  m.fire("detail.game", { system = "nds", code = "ZZZZ", sha256 = "00", title = "Meadow Courier" })
  local s = joined(m.trees.detail)
  t.ok(s:find("Not supported", 1, true), s)
  t.ok(s:find("Meadow Courier can't be randomized.", 1, true), s)
  t.ok(not s:find("Each variant", 1, true), s)
end)

t.case("unsupported game without a title and the German card", function()
  local m = mock.load_bundle({ language = "de" })
  m.fire("detail.game", { system = "gba", code = "", sha256 = "00", title = "" })
  t.ok(joined(m.trees.detail):find("Dieses Spiel kann nicht randomisiert werden.", 1, true))
  m.fire("detail.game", { system = "3ds", code = "000400000011C400", sha256 = "00", title = "Demo" })
  local s = joined(m.trees.detail)
  t.ok(s:find("Unterstützt", 1, true) and s:find("Spielstand-Slot", 1, true), s)
end)

t.case("no game clears the card", function()
  local m = mock.load_bundle()
  m.fire("detail.game", { system = "gba", code = "AXVE", sha256 = "00", title = "X" })
  t.ok(m.trees.detail)
  m.fire("detail.game", nil)
  t.eq(m.trees.detail, nil)
end)

t.case("the card never carries preset strings or other variant data", function()
  local m = mock.load_bundle()
  m.fire("detail.game", { system = "nds", code = "IPKE", sha256 = "00", title = "T" })
  local function walk(tr)
    for k, v in pairs(tr) do
      if type(v) == "string" then t.ok(not v:match("^%d%d%d[A-Za-z0-9+/=]+$") or #v < 40, "settings string in card") end
      if type(v) == "table" then walk(v) end
    end
  end
  walk(m.trees.detail)
end)

t.case("code matching: case, globs and system", function()
  t.ok(games.supported("nds", "ipke"))
  t.ok(games.supported("gb", "POKEMON RED"))
  t.ok(games.supported("gb", "POKEMON YEL"))
  t.ok(games.supported("gbc", "PM_CRYSTAL"))
  t.ok(games.supported("3ds", "0004000000164800"))
  t.ok(not games.supported("gba", "IPKE"), "code of another system")
  t.ok(not games.supported("nds", ""))
  t.ok(not games.supported("snes", "IPKE"))
  t.ok(not games.supported("3ds", "0004000000164801"))
end)

local SUP = { id = "g1", system = "nds", code = "IPKE", sha256 = "00", title = "Coral Saga: Ember" }

t.case("card shows the engine state and the variants of the game", function()
  local m = mock.load_bundle({
    engine = { offered = true, version = "1.6.2", on_pc = true },
    variants_list = {
      { id = "a", name = "My run", slot = "var-a", preset_id = "classic", state = "ready" },
      { id = "b", name = "Second", slot = "var-b", state = "building" },
    },
  })
  m.fire("detail.game", SUP)
  local s = joined(m.trees.detail)
  t.ok(s:find("Engine 1.6.2 is ready on this PC.", 1, true), s)
  t.ok(s:find("Your variants", 1, true), s)
  local rows = require("ui_validator").find(m.trees.detail, "variants").rows
  t.eq(#rows, 2)
  t.eq(rows[1].title, "My run"); t.eq(rows[1].meta, "ready")
  t.eq(rows[2].meta, "building")
  -- never the preset id, slot or anything else of the variant
  t.ok(not s:find("classic", 1, true) and not s:find("var-a", 1, true))
end)

t.case("card: engine not offered, not on this PC, no variants, many variants", function()
  local m = mock.load_bundle({ engine = { offered = false } })
  m.fire("detail.game", SUP)
  local s = joined(m.trees.detail)
  t.ok(s:find("does not offer the randomizer engine", 1, true), s)
  t.ok(s:find("no variants of this game yet", 1, true), s)
  m = mock.load_bundle()
  m.fire("detail.game", SUP)
  t.ok(joined(m.trees.detail):find("offered and not on this PC yet", 1, true))
  local many = {}
  for i = 1, 8 do many[i] = { id = "x" .. i, name = "V" .. i, state = "failed" } end
  m = mock.load_bundle({ variants_list = many })
  m.fire("detail.game", SUP)
  t.eq(#require("ui_validator").find(m.trees.detail, "variants").rows, 5)
  t.ok(joined(m.trees.detail):find("and 3 more", 1, true))
end)

t.case("card guards older apps and failing calls", function()
  for _, o in ipairs({ { no_list = true, no_engine = true }, { list_error = true, no_engine = true } }) do
    local m = mock.load_bundle(o)
    m.fire("detail.game", SUP)
    local s = joined(m.trees.detail)
    t.ok(s:find("Supported", 1, true), s)
    t.ok(not s:find("Engine", 1, true) and not s:find("variants", 1, true), s)
  end
  local m = mock.load_bundle({ no_list = true })
  m.fire("detail.game", SUP)
  t.ok(joined(m.trees.detail):find("Engine 1.6.2", 1, true), "engine alone still shows")
end)

t.case("unsupported games show no variants or engine; variants.state refreshes the card; German", function()
  local m = mock.load_bundle({ language = "de", variants_list = { { id = "a", name = "Lauf", state = "needs_rebuild" } } })
  m.fire("detail.game", { system = "nds", code = "ZZZZ", sha256 = "00", title = "X" })
  t.ok(not joined(m.trees.detail):find("Engine", 1, true))
  m.fire("detail.game", SUP)
  t.eq(require("ui_validator").find(m.trees.detail, "variants").rows[1].meta, "muss neu gebaut werden")
  m.trees.detail = nil
  m.fire("variants.state", { id = 1, state = "ready", progress = 1 })
  t.ok(m.trees.detail, "card rebuilt on variants.state")
  m.fire("detail.game", nil)
  m.fire("variants.state", { id = 1, state = "ready" })
  t.eq(m.trees.detail, nil)
end)

t.case("the list is asked for with the game id and left out without one", function()
  local m = mock.load_bundle({ variants_list = { { id = "a", name = "My run", state = "ready" } } })
  m.fire("detail.game", SUP)
  t.eq(m.list_game_id, "g1")
  m.fire("detail.game", { system = "nds", code = "IPKE", sha256 = "00", title = "T" })
  local s = joined(m.trees.detail)
  t.ok(not s:find("variants", 1, true) and not s:find("My run", 1, true), s)
  t.ok(s:find("Engine", 1, true), "engine line stays")
end)
