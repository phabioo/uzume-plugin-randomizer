local t = require("t")
local mock = require("fb_mock")
local json = require("json")

local function read(path) return mock.read_file(path) end

t.case("plugin/main.lua is up to date", function()
  local p = assert(io.popen("lua5.4 tools/bundle.lua --check 2>&1"))
  local out = p:read("a")
  t.ok(p:close(), out)
end)

t.case("sources use no sandbox-forbidden globals", function()
  local p = assert(io.popen("ls src/*.lua"))
  for path in p:lines() do
    local src = read(path)
    for _, bad in ipairs({ "io%.", "os%.", "package%.", "debug%.", "dofile", "loadstring", "[^%w_]load%(" }) do
      t.ok(not src:find(bad), path .. " uses " .. bad)
    end
  end
  p:close()
end)

t.case("manifest", function()
  local m = json.decode(read("plugin/manifest.json"))
  t.eq(m.id, "uzume.randomizer")
  t.eq(m.name, "Randomizer")
  t.eq(m.version, "0.1.0")
  t.eq(m.api, 1)
  t.eq(m.type, "script")
  t.eq(m.entry, "main.lua")
  t.eq(m.permissions, { "ui", "variants.build" })
  t.eq(m.ui, { detail = true })
  t.ok(m.run_settings == nil, "no run settings: Uzume draws the run section")
  local systems = {}
  for _, g in ipairs(m.games) do systems[g.system] = true end
  t.eq(systems, { gb = true, gbc = true, gba = true, nds = true, ["3ds"] = true })
end)

t.case("i18n: German has exactly the keys of English", function()
  local en = mock.read_json_flat(read("plugin/i18n/en.json"))
  local de = mock.read_json_flat(read("plugin/i18n/de.json"))
  for k in pairs(en) do t.ok(de[k] ~= nil, "de lacks " .. k) end
  for k in pairs(de) do t.ok(en[k] ~= nil, "en lacks " .. k) end
  t.ok(de.slot_note ~= en.slot_note)
end)

t.case("every i18n key used in src exists", function()
  local en = mock.read_json_flat(read("plugin/i18n/en.json"))
  local p = assert(io.popen("ls src/*.lua"))
  for path in p:lines() do
    for key in read(path):gmatch('%f[%w_]t%("([%w_]+)"%s*[,)]') do t.ok(en[key], path .. ": missing key " .. key) end
  end
  p:close()
  for _, id in ipairs(require("presets").order) do
    t.ok(en["preset_" .. id .. "_label"] and en["preset_" .. id .. "_hint"], "preset text " .. id)
  end
end)

t.case("bundled plugin loads in the mock sandbox", function()
  local m = mock.load_bundle({ language = "de" })
  t.eq(m.logs[1].text, "Randomizer 0.1.0 geladen.")
end)
