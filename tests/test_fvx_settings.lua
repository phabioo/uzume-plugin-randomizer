local t = require("t")
local fvx = require("fvx_settings")
local presets = require("presets")

local function all_options()
  local list = {}
  for _, g in ipairs(fvx.groups) do
    for _, o in ipairs(g.options) do list[#list + 1] = o end
  end
  for _, o in ipairs(fvx.hidden) do list[#list + 1] = o end
  return list
end

local function bytes_of(s) return assert(fvx._b64_decode(s:sub(4))) end

local function string_of(bytes) return "428" .. fvx._b64_encode(bytes) end

local function copy(tbl)
  local c = {}
  for k, v in pairs(tbl) do c[k] = v end
  return c
end

-- Fix the checksum of a modified byte list (data + name length + name already in place, 8 trailing bytes present).
local function refresh_crc(b)
  local body = #b - 8
  local crc = fvx._crc32(b, body)
  b[body + 1], b[body + 2] = (crc >> 24) & 0xFF, (crc >> 16) & 0xFF
  b[body + 3], b[body + 4] = (crc >> 8) & 0xFF, crc & 0xFF
end

t.case("crc32 and base64 known vectors", function()
  local b = {}
  for i = 1, 9 do b[i] = ("123456789"):byte(i) end
  t.eq(fvx._crc32(b, 9), 0xCBF43926)
  t.eq(fvx._b64_encode({ 0x66 }), "Zg==")
  t.eq(fvx._b64_encode({ 0x66, 0x6F }), "Zm8=")
  t.eq(fvx._b64_encode({ 0x66, 0x6F, 0x6F }), "Zm9v")
  t.eq(fvx._b64_decode("Zm9vYg=="), { 0x66, 0x6F, 0x6F, 0x62 })
  t.eq(fvx._b64_decode("Zg="), nil)
  t.eq(fvx._b64_decode("Zg=a"), nil)
  t.eq(fvx._b64_decode("Zm9v*A=="), nil)
end)

t.case("presets round-trip byte-identically", function()
  for _, name in ipairs(presets.order) do
    local s = presets.settings[name]["428"]
    local o, err = fvx.decode(s)
    t.ok(o, name .. ": " .. tostring(err))
    t.eq(fvx.encode(o), s, name)
  end
end)

t.case("preset values look plausible", function()
  local n = fvx.decode(presets.settings.nuzlocke["428"])
  t.eq(n.starters_mod, "random_with_two_evolutions")
  t.eq(n.starters_no_legendaries, true)
  t.eq(n.starters_bst_maximum, 400)
  t.eq(n.randomize_wild_pokemon, true)
  t.eq(n.wild_zone_mod, "named_location")
  t.eq(n.similar_strength_encounters, true)
  t.eq(n.block_wild_legendaries, true)
  t.eq(n.trainers_mod, "random")
  t.eq(n.static_pokemon_mod, "similar_strength")
  local c = fvx.decode(presets.settings.chaos["428"])
  t.eq(c.base_stats_mod, "random")
  t.eq(c.abilities_mod, "randomize")
  t.eq(c.trainers_block_legendaries, false)
  t.eq(c.tms_hms_compatibility_mod, "completely_random")
end)

-- Bytes 0-68 of a fresh engine Settings, worked out by hand from the field initialisers (non-zero bytes only):
-- the first value of every enum, wonder guard and the three "block" flags on, whole-game wild areas with wild
-- randomisation off, all generations allowed, level modifiers 0 (stored as -28), 40 for "make evolutions easier",
-- exp curve medium fast (the engine leaves it unset until a ROM is loaded; that choice is ours).
local DEFAULT_BYTES = {
  [1] = 0x08, [2] = 0x04, [3] = 0x05, [4] = 0x04, [11] = 0x04, [13] = 0x01, [14] = 0xE4, [15] = 0x09,
  [17] = 0x11, [18] = 0x04, [19] = 0x01, [20] = 0x14, [23] = 0x14, [25] = 0x40, [26] = 0x04, [28] = 0x01,
  [29] = 0x18, [30] = 0xFF, [38] = 0xE4, [39] = 0x04, [40] = 0xE4, [41] = 0x01, [43] = 0x08, [44] = 0x09,
  [45] = 0xE4, [49] = 0xE4, [51] = 0x02, [53] = 0x01, [55] = 0x01, [56] = 0x01, [62] = 0x09, [66] = 0x28,
  [67] = 0x01,
}

t.case("encode(defaults) matches the hand-derived default string", function()
  local b = bytes_of(fvx.encode(fvx.defaults()))
  t.eq(#b, 69 + 1 + 4 + 4)
  for i = 0, 68 do t.eq(b[i + 1], DEFAULT_BYTES[i] or 0, "byte " .. i) end
  t.eq(b[70], 0) -- empty ROM name
  local crc = fvx._crc32(b, 70)
  t.eq((b[71] << 24) | (b[72] << 16) | (b[73] << 8) | b[74], crc)
  t.eq({ b[75], b[76], b[77], b[78] }, { 0, 0, 0, 0 })
  t.ok(fvx.encode(fvx.defaults()):sub(1, 3) == "428")
  t.eq(fvx.encode({}), fvx.encode(fvx.defaults()))
  t.eq(fvx.decode(fvx.encode(fvx.defaults())), fvx.defaults())
end)

t.case("schema is consistent", function()
  local seen = {}
  for _, g in ipairs(fvx.groups) do
    t.ok(g.id:match("^[a-z_]+$"), g.id)
    for _, o in ipairs(g.options) do
      t.ok(o.id:match("^[a-z][a-z0-9_]*$"), o.id)
      t.ok(not seen[o.id], "duplicate " .. o.id)
      seen[o.id] = o
    end
  end
  for id, o in pairs(seen) do
    t.ok(o.kind == "bool" or o.kind == "enum" or o.kind == "int", id)
    if o.kind == "enum" then
      local ok = false
      for _, c in ipairs(o.choices) do if c == o.default then ok = true end end
      t.ok(ok, id .. " default not a choice")
    elseif o.kind == "int" then
      t.ok(o.default >= o.min and o.default <= o.max, id .. " default out of range")
      t.ok(not o.ui_min or (o.ui_min >= o.min and o.ui_max <= o.max), id)
    end
    for parent, value in pairs(o.requires or {}) do
      local p = seen[parent]
      t.ok(p, id .. " requires unknown " .. parent)
      if p.kind == "enum" then
        local ok = false
        for _, c in ipairs(p.choices) do if c == value then ok = true end end
        t.ok(ok, id .. " requires bad choice")
      else
        t.eq(type(value), "boolean", id)
      end
    end
  end
  t.eq(#fvx.groups, 9)
end)

t.case("every option on its own round-trips", function()
  local base = fvx.defaults()
  local count = 0
  for _, o in ipairs(all_options()) do
    local values
    if o.kind == "bool" then
      values = { not o.default }
    elseif o.kind == "enum" then
      values = o.choices
    else
      values = { o.min, o.max, (o.min + o.max) // 2, o.default + 1 <= o.max and o.default + 1 or o.default - 1 }
    end
    for _, v in ipairs(values) do
      local x = copy(base)
      x[o.id] = v
      local s = fvx.encode(x)
      local back, err = fvx.decode(s)
      t.ok(back, o.id .. ": " .. tostring(err))
      t.eq(back, x, o.id .. "=" .. tostring(v))
      t.eq(fvx.encode(back), s, o.id)
      count = count + 1
    end
  end
  t.ok(count > 300, "only " .. count)
end)

t.case("a single option changes bits only where it lives", function()
  -- flipping an option must differ from the defaults in exactly its own byte(s) plus the checksum
  local base = bytes_of(fvx.encode(fvx.defaults()))
  for _, o in ipairs(all_options()) do
    if o.kind == "bool" then
      local x = fvx.defaults()
      x[o.id] = not o.default
      local b = bytes_of(fvx.encode(x))
      local diff = {}
      for i = 1, 69 do if b[i] ~= base[i] then diff[#diff + 1] = i - 1 end end
      t.eq(#diff, 1, o.id)
      t.eq(diff[1], o.at.byte, o.id)
    end
  end
end)

local function random_options(rng)
  local x = fvx.defaults()
  for _, o in ipairs(all_options()) do
    if o.kind == "bool" then
      x[o.id] = rng(0, 1) == 1
    elseif o.kind == "enum" then
      x[o.id] = o.choices[rng(1, #o.choices)]
    else
      local r = rng(1, 6)
      if r == 1 then x[o.id] = o.min elseif r == 2 then x[o.id] = o.max else x[o.id] = rng(o.min, o.max) end
    end
  end
  return x
end

t.case("seeded random option sets round-trip", function()
  math.randomseed(20261101)
  local seen = {}
  for _ = 1, 300 do
    local x = random_options(math.random)
    local s = fvx.encode(x)
    local back, err = fvx.decode(s)
    t.ok(back, tostring(err))
    t.eq(back, x)
    t.eq(fvx.encode(back), s)
    seen[s] = true
  end
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  t.eq(n, 300)
end)

t.case("encode clamps ints, fills missing keys and defaults bad choices", function()
  local s = fvx.encode({ trainers_level_modifier = 9999, wild_level_modifier = -9999, custom_starter_1 = 70000,
    guaranteed_move_count = 0, trainers_mod = "nope", starters_bst_maximum = 5000.0, race_mode = 1 })
  local o = fvx.decode(s)
  t.eq(o.trainers_level_modifier, 155)
  t.eq(o.wild_level_modifier, -100)
  t.eq(o.custom_starter_1, 65535)
  t.eq(o.guaranteed_move_count, 2)
  t.eq(o.trainers_mod, "unchanged")
  t.eq(o.starters_bst_maximum, 4095)
  t.eq(o.race_mode, true)
  t.eq(o.allow_gen_3, true) -- missing key -> default
end)

t.case("values only the string holds survive: custom starters, BST limits, unknown tweak bits, ROM name", function()
  local x = fvx.defaults()
  x.starters_mod = "custom"
  x.custom_starter_1, x.custom_starter_2, x.custom_starter_3 = 1, 0x1234, 0xFFFF
  x.starters_bst_minimum, x.starters_bst_maximum = 0xABC, 0x123
  x.misc_tweaks_other = 0x2A
  x.tweak_no_ev_yields, x.tweak_bw_exp_patch = true, true
  local b = bytes_of(fvx.encode(x))
  t.eq({ b[6], b[7], b[8], b[9], b[10], b[11] }, { 1, 0, 0x34, 0x12, 0xFF, 0xFF })
  t.eq({ b[59], b[60], b[61] }, { 0x1A, 0xBC, 0x23 })
  t.eq({ b[35], b[36], b[37], b[38] }, { 0x02 | (0x2A << 2), 0, 0, 1 }) -- big endian misc tweak value
  t.eq(fvx.decode(fvx.encode(x)), x)

  -- a string from the engine with a ROM name keeps the name
  local nb = bytes_of(fvx.encode(fvx.defaults()))
  local named = {}
  for i = 1, 69 do named[i] = nb[i] end
  named[70] = 3
  for _, c in ipairs({ 65, 66, 67 }) do named[#named + 1] = c end
  for i = 71, 78 do named[#named + 1] = nb[i] end
  refresh_crc(named)
  local o, err = fvx.decode(string_of(named))
  t.ok(o, tostring(err))
  t.eq(o.rom_name, "ABC")
  t.eq(fvx.encode(o), string_of(named))
end)

t.case("decode follows the engine: first set bit wins, none set gives the first choice, two bits are refused", function()
  local b = bytes_of(fvx.encode(fvx.defaults()))
  local function with(index, value)
    local c = {}
    for i = 1, #b do c[i] = b[i] end
    c[index + 1] = value
    refresh_crc(c)
    return string_of(c)
  end
  t.eq(fvx.decode(with(3, 0x04)).abilities_mod, "unchanged") -- neither unchanged nor randomize set
  t.eq(fvx.decode(with(3, 0x02)).abilities_mod, "randomize")
  local o, err = fvx.decode(with(3, 0x03))
  t.eq(o, nil)
  t.eq(err, "bad_value")
  t.eq(select(2, fvx.decode(with(48, 6))), "bad_value") -- unknown exp curve
  t.eq(fvx.decode(with(54, 5)).starters_single_type, "water")
  t.eq(fvx.decode(with(54, 0x1F)).starters_single_type, "none")
  t.eq(fvx.decode(with(15, 0x00)).wild_zone_mod, "none")
end)

t.case("bad input is refused with a code", function()
  local good = presets.settings.nuzlocke["428"]
  t.eq({ fvx.decode(good) ~= nil }, { true })
  t.eq(select(2, fvx.decode(nil)), "bad_input")
  t.eq(select(2, fvx.decode(42)), "bad_input")
  t.eq(select(2, fvx.decode("")), "bad_version")
  t.eq(select(2, fvx.decode("427" .. good:sub(4))), "bad_version")
  t.eq(select(2, fvx.decode("4280")), "bad_base64")
  t.eq(select(2, fvx.decode("428!!!!")), "bad_base64")
  t.eq(select(2, fvx.decode("garbage string")), "bad_version")
  t.eq(select(2, fvx.decode("428AAAA")), "bad_length")
  t.eq(select(2, fvx.decode(good:sub(1, #good - 4))), "bad_length")
  -- flip one data bit: base64 still valid, checksum fails
  local b = bytes_of(good)
  b[4] = b[4] ~ 0x01
  t.eq(select(2, fvx.decode(string_of(b))), "bad_checksum")
  -- name length that does not fit the string
  local c = bytes_of(good)
  c[70] = 5
  refresh_crc(c)
  t.eq(select(2, fvx.decode(string_of(c))), "bad_length")
  -- trailing data
  local d = bytes_of(good)
  d[#d + 1] = 0
  t.eq(select(2, fvx.decode(string_of(d))), "bad_length")
end)
