local t = require("t")
local mock = require("fb_mock")
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
