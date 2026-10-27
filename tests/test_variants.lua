local t = require("t")
local mock = require("fb_mock")
local presets = require("presets")

t.case("register is called once with engine, three presets and the games", function()
  local m = mock.load_bundle()
  t.eq(m.register_calls, 1)
  t.eq(m.registered.engine, "randomizer")
  t.eq(#m.registered.presets, 3)
  local ids = {}
  for i, p in ipairs(m.registered.presets) do ids[i] = p.id end
  t.eq(ids, { "nuzlocke", "classic", "chaos" })
  t.ok(#m.registered.games >= 5)
end)

t.case("presets carry translated labels and hints, no Custom preset", function()
  local m = mock.load_bundle()
  local by = {}
  for _, p in ipairs(m.registered.presets) do by[p.id] = p end
  t.eq(by.nuzlocke.label, "Nuzlocke friendly")
  t.eq(by.nuzlocke.hint, "Fair start, game stays finishable")
  t.eq(by.classic.hint, "Creatures and items shuffled")
  t.eq(by.chaos.hint, "Everything that can change")
  t.ok(by.custom == nil)
  local de = mock.load_bundle({ language = "de" })
  t.eq(de.registered.presets[1].label, "Nuzlocke-freundlich")
end)

t.case("every preset has a settings string that starts with its settings version", function()
  local m = mock.load_bundle()
  for _, p in ipairs(m.registered.presets) do
    local n = 0
    for version, s in pairs(p.settings) do
      n = n + 1
      t.ok(version:match("^%d%d%d$"), p.id .. ": version key " .. version)
      t.ok(s:match("^%d%d%d[A-Za-z0-9+/=]+$"), p.id .. ": settings string shape")
      t.eq(s:sub(1, 3), version, p.id .. ": prefix")
    end
    t.ok(n >= 1, p.id .. ": no settings")
    t.ok(p.settings[presets.SETTINGS_VERSION], p.id .. ": settings for the current version")
  end
end)

t.case("the three strings differ", function()
  local s = presets.settings
  t.ok(s.nuzlocke["428"] ~= s.classic["428"] and s.classic["428"] ~= s.chaos["428"] and s.nuzlocke["428"] ~= s.chaos["428"])
end)

t.case("games table covers all five systems with codes", function()
  local m = mock.load_bundle()
  local seen = {}
  for _, g in ipairs(m.registered.games) do
    t.ok(#g.codes > 0, g.system .. " has no codes")
    seen[g.system] = true
  end
  t.eq(seen, { gb = true, gbc = true, gba = true, nds = true, ["3ds"] = true })
end)

t.case("a registration error is logged, not raised", function()
  local m = mock.load_bundle({ register_error = "engine not offered" })
  local found
  for _, l in ipairs(m.logs) do if l.level == "error" then found = l.text end end
  t.ok(found and found:find("engine not offered", 1, true))
end)
