local t = require("t")
local mock = require("uz_mock")
local validator = require("ui_validator")
local fvx = require("fvx_settings")
local own_presets = require("own_presets")

local function find(m, id) return validator.find(m.trees.screen, id) end
local function entry(n, name) return { id = "own-" .. n, name = name or ("Preset " .. n), settings = fvx.encode(fvx.defaults()) } end
local function entries(n)
  local list = {}
  for i = 1, n do list[i] = entry(i) end
  return list
end
local function toast_titles(m)
  local out = {}
  for i, x in ipairs(m.toasts) do out[i] = x.title end
  return out
end
local function save_as(m, name)
  m.action("name", name)
  m.action("save_new")
end

-- ---------------------------------------------------------------- module

local function module_env(m)
  return own_presets.new({
    store = m.uz.store, variants = m.uz.variants, hint = "own",
    builtin = function() return { { id = "classic", label = "C", hint = "h", settings = { ["428"] = "428A" } } } end,
    games = function() return { { system = "nds", codes = { "IPKE" } } } end,
  })
end

t.case("module: add, update and remove go through the store with the read revision", function()
  local m = mock.new({ permissions = { ui = true, ["variants.build"] = true, store = true } })
  local own = module_env(m)
  t.ok(own:reload())
  local id = own:add("First", "428AAAA")
  t.eq(id, "own-1")
  t.eq(m.store_data.presets.rev, 1)
  t.eq(m.store_data.presets.value, { { id = "own-1", name = "First", settings = "428AAAA" } })
  t.eq(own:add("Second", "428BBBB"), "own-2")
  t.ok(own:update("own-1", "Renamed", "428CCCC"))
  t.eq(own:find("own-1").name, "Renamed")
  t.ok(own:remove("own-2"))
  t.eq(#own.list, 1)
  t.eq(own:add("Third", "428DDDD"), "own-2", "ids restart above the highest in use")
  t.eq(own:update("own-9", "x", "428E"), nil)
  t.eq(select(2, own:update("own-9", "x", "428E")), "not_found")
  t.eq(m.register_calls, 5, "registered after each successful write")
end)

t.case("module: the registered list is built-ins first, own presets with the hint and the version key", function()
  local m = mock.new()
  local own = module_env(m)
  own:reload()
  own:add("Mine", "428ZZZZ")
  local reg = m.registered
  t.eq(#reg.presets, 2)
  t.eq(reg.presets[1].id, "classic")
  t.eq(reg.presets[2], { id = "own-1", label = "Mine", hint = "own", settings = { ["428"] = "428ZZZZ" } })
  t.eq(reg.games, { { system = "nds", codes = { "IPKE" } } })
end)

t.case("module: invalid stored entries are dropped", function()
  local m = mock.new({ store = { presets = {
    entry(1), { id = "evil", name = "x", settings = "428AAAA" }, { id = "own-2", name = "", settings = "428AAAA" },
    { id = "own-3", name = "ok", settings = "not a string" }, "text", { id = "own-4", name = ("x"):rep(61), settings = "428AAAA" },
    entry(5),
  } } })
  local own = module_env(m)
  own:reload()
  local ids = {}
  for i, p in ipairs(own.list) do ids[i] = p.id end
  t.eq(ids, { "own-1", "own-5" })
end)

t.case("module: a value that is not a list gives an empty list", function()
  local m = mock.new({ store = { presets = "oops" } })
  local own = module_env(m)
  t.ok(own:reload())
  t.eq(#own.list, 0)
end)

t.case("module: at most 29 presets", function()
  local m = mock.new({ store = { presets = entries(29) } })
  local own = module_env(m)
  own:reload()
  t.eq(#own.list, 29)
  local id, code = own:add("one too many", "428AAAA")
  t.eq(id, nil)
  t.eq(code, "limit")
  t.eq(m.store_puts, 0)
  -- more than 29 stored (written by hand): the extra ones are not registered
  local m2 = mock.new({ store = { presets = entries(31) } })
  local own2 = module_env(m2)
  own2:reload()
  t.eq(#own2.list, 29)
end)

t.case("module: a stale write is refused, the store is read again and nothing is overwritten", function()
  local m = mock.new()
  local own = module_env(m)
  own:reload()
  m.external_write("presets", { entry(7, "From the other PC") })
  local id, code = own:add("Mine", "428AAAA")
  t.eq(id, nil)
  t.eq(code, "conflict")
  t.eq(m.store_data.presets.value[1].name, "From the other PC")
  t.eq(#m.store_data.presets.value, 1)
  t.eq(own.list[1].id, "own-7", "the list now shows the other PC's presets")
  t.eq(#m.uz.store.conflicts("presets"), 1, "our attempt is kept as a conflict copy")
  -- after reading again, saving works and clears the conflict
  t.ok(own:add("Mine", "428AAAA"))
  t.eq(#m.store_data.presets.value, 2)
end)

t.case("module: too_large and quota_exceeded are reported, other failures are 'failed'", function()
  for _, code in ipairs({ "too_large", "quota_exceeded" }) do
    local m = mock.new({ store_put_error = code })
    local own = module_env(m)
    own:reload()
    local id, got = own:add("x", "428AAAA")
    t.eq(id, nil)
    t.eq(got, code)
    t.eq(#own.list, 0)
  end
  local m = mock.new({ store_put_error = "weird" })
  local own = module_env(m)
  own:reload()
  t.eq(select(2, own:add("x", "428AAAA")), "failed")
end)

t.case("module: a failing store.get is survived", function()
  local m = mock.new({ store_get_error = "boom" })
  local own = module_env(m)
  t.eq(own:reload(), nil)
  t.eq(#own.list, 0)
  t.ok(own:register())
end)

t.case("module: without a store nothing can be saved", function()
  local m = mock.new({ no_store = true })
  local own = module_env(m)
  t.eq(own:available(), false)
  t.eq(own:reload(), nil)
  t.eq(select(2, own:add("x", "428AAAA")), "no_store")
  t.ok(own:register())
end)

-- ---------------------------------------------------------------- plugin

t.case("at load the store is read and the built-ins plus the own presets are registered once", function()
  local m = mock.load_bundle({ store = { presets = { entry(1, "Nuz hard"), entry(2, "Wild") } } })
  t.eq(m.register_calls, 1)
  t.eq(#m.registered.presets, 5)
  t.eq(m.registered.presets[4].label, "Nuz hard")
  t.eq(m.registered.presets[4].hint, "Your own preset")
  t.eq(m.registered.presets[4].id, "own-1")
  local rows = find(m, "own_list").rows
  t.eq(#rows, 2)
  t.eq(rows[1].title, "Nuz hard")
  t.eq(rows[1].meta, "Your preset")
end)

t.case("built-ins are registered even when the store cannot be read", function()
  local m = mock.load_bundle({ store_get_error = "boom" })
  t.eq(m.register_calls, 1)
  t.eq(#m.registered.presets, 3)
  t.ok(m.trees.screen)
end)

t.case("save as preset: store, registration and list", function()
  local m = mock.load_bundle()
  t.eq(find(m, "save").disabled, true, "no name yet")
  m.action("set:race_mode", true)
  m.action("name", "  My run  ")
  t.eq(find(m, "save").disabled, false)
  m.action("save_new")
  local stored = m.store_data.presets.value
  t.eq(#stored, 1)
  t.eq(stored[1].name, "My run")
  t.eq(stored[1].settings, fvx.encode((function() local o = fvx.defaults(); o.race_mode = true; return o end)()))
  t.eq(m.register_calls, 2)
  t.eq(#m.registered.presets, 4)
  t.eq(m.registered.presets[4].label, "My run")
  t.eq(m.registered.presets[4].settings, { ["428"] = stored[1].settings })
  t.eq(find(m, "own_list").rows[1].title, "My run")
  t.eq(toast_titles(m), { "Preset saved" })
  -- now editing it: the other buttons appear
  t.ok(find(m, "save_changes"))
  t.ok(find(m, "delete"))
  t.eq(find(m, "base").selected, "own:own-1")
  t.eq(find(m, "own_list").selected, "own-1")
end)

t.case("the name field enables the buttons without a full redraw", function()
  local m = mock.load_bundle()
  m.action("name", "A")
  t.eq(find(m, "save").disabled, false)
  m.action("name", "   ")
  t.eq(find(m, "save").disabled, true)
  m.action("name", ("x"):rep(61))
  t.eq(find(m, "save").disabled, true)
  m.action("name", ("ä"):rep(60))
  t.eq(find(m, "save").disabled, false)
  m.action("save_new")
  t.eq(#m.store_data.presets.value, 1)
end)

t.case("save without a valid name does nothing", function()
  local m = mock.load_bundle()
  m.action("save_new")
  t.eq(m.store_puts, 0)
end)

t.case("loading an own preset from the list and from 'Start from' fills the editor", function()
  local o = fvx.defaults()
  o.bst_mod = "shuffle"
  local m = mock.load_bundle({ store = { presets = { { id = "own-1", name = "Shuffled", settings = fvx.encode(o) } } } })
  m.action("load_own", "own-1")
  t.eq(find(m, "o_bst_mod").selected, "shuffle")
  t.eq(find(m, "base").selected, "own:own-1")
  t.ok(find(m, "delete"), "editing an own preset")
  m.action("base", "default")
  t.eq(find(m, "o_bst_mod").selected, "unchanged")
  t.ok(not find(m, "delete"))
  m.action("base", "own:own-1")
  t.eq(find(m, "o_bst_mod").selected, "shuffle")
  t.eq(find(m, "name").text, "Shuffled")
  -- the select offers default, three built-ins and the own preset
  t.eq(#find(m, "base").options, 5)
end)

t.case("save changes replaces the preset in place", function()
  local m = mock.load_bundle({ store = { presets = { entry(1, "Old name") } } })
  m.action("load_own", "own-1")
  m.action("set:race_mode", true)
  m.action("name", "New name")
  m.action("save_changes")
  local stored = m.store_data.presets.value
  t.eq(#stored, 1)
  t.eq(stored[1].name, "New name")
  t.ok(stored[1].settings ~= entry(1).settings)
  t.eq(m.registered.presets[4].label, "New name")
  t.eq(find(m, "own_list").rows[1].title, "New name")
end)

t.case("delete asks for confirmation and removes the preset", function()
  local m = mock.load_bundle({ store = { presets = { entry(1, "Gone soon"), entry(2, "Stays") } } })
  m.action("load_own", "own-1")
  local btn = find(m, "delete")
  t.eq(btn.variant, "danger")
  t.ok(btn.confirm and btn.confirm.danger == true and btn.confirm.title and btn.confirm.text)
  m.action("delete")
  t.eq(#m.store_data.presets.value, 1)
  t.eq(m.store_data.presets.value[1].id, "own-2")
  t.eq(#m.registered.presets, 4)
  t.eq(find(m, "own_list").rows[1].title, "Stays")
  t.ok(not find(m, "delete"))
  t.eq(find(m, "base").selected, "default")
end)

t.case("conflict: nothing is overwritten, the editor state stays, the person is told", function()
  local m = mock.load_bundle()
  m.action("set:race_mode", true)
  m.action("name", "Mine")
  local string_before = find(m, "string").value
  m.external_write("presets", { entry(7, "From the other PC") }) -- no event yet: the plugin still holds the old revision
  m.action("save_new")
  t.eq(#m.store_data.presets.value, 1)
  t.eq(m.store_data.presets.value[1].name, "From the other PC")
  t.eq(#m.uz.store.conflicts("presets"), 1)
  t.eq(toast_titles(m), { "Presets changed" })
  t.ok(m.toasts[1].text:find("another PC", 1, true))
  t.eq(find(m, "string").value, string_before, "editor state kept")
  t.eq(find(m, "name").text, "Mine")
  t.eq(find(m, "own_list").rows[1].title, "From the other PC", "list reloaded")
  t.eq(#m.registered.presets, 4, "registered from the store again")
  -- saving again now works against the new revision
  m.action("save_new")
  t.eq(#m.store_data.presets.value, 2)
end)

t.case("store.changed from another PC reloads, registers again and keeps the editor state", function()
  local m = mock.load_bundle()
  m.action("set:race_mode", true)
  local string_before = find(m, "string").value
  m.external_write("presets", { entry(3, "Remote") }, true)
  t.eq(find(m, "own_list").rows[1].title, "Remote")
  t.eq(m.registered.presets[4].label, "Remote")
  t.eq(find(m, "string").value, string_before)
  -- other keys are ignored
  local calls = m.register_calls
  m.fire("store.changed", "something_else", "app")
  t.eq(m.register_calls, calls)
end)

t.case("store.changed that removes the preset being edited leaves editing mode", function()
  local m = mock.load_bundle({ store = { presets = { entry(1, "Mine") } } })
  m.action("load_own", "own-1")
  t.ok(find(m, "delete"))
  m.external_write("presets", {}, true)
  t.ok(not find(m, "delete"))
  t.eq(find(m, "base").selected, "default")
  t.eq(#m.registered.presets, 3)
end)

t.case("store.conflict tells the person", function()
  local m = mock.load_bundle()
  m.fire("store.conflict", "presets", "app")
  t.eq(toast_titles(m), { "Presets changed" })
  m.fire("store.conflict", "other", "app")
  t.eq(#m.toasts, 1)
end)

t.case("reloaded event restores the list from the store", function()
  local m = mock.load_bundle()
  m.external_write("presets", { entry(1, "After reload") })
  m.fire("reloaded", { ms = 5 })
  t.eq(find(m, "own_list").rows[1].title, "After reload")
  t.eq(#m.registered.presets, 4)
end)

t.case("29 presets: save is disabled and a forced save is refused with a toast", function()
  local m = mock.load_bundle({ store = { presets = entries(29) } })
  t.eq(#m.registered.presets, 32)
  m.action("name", "Number 30")
  t.eq(find(m, "save").disabled, true)
  local note
  for _, x in ipairs(validator.all(m.trees.screen, "text")) do if x.text:find("29 presets", 1, true) then note = true end end
  t.ok(note, "limit note")
  m.action("save_new")
  t.eq(m.store_puts, 0)
  t.eq(toast_titles(m), { "Preset not saved" })
  t.eq(#m.store_data.presets.value, 29)
  -- the select stays within 100 options
  t.eq(#find(m, "base").options, 33)
  t.ok(validator.validate(m.trees.screen))
end)

t.case("too large and quota: toast, list unchanged", function()
  for code, text in pairs({ too_large = "too large", quota_exceeded = "no storage space" }) do
    local m = mock.load_bundle({ store_put_error = code })
    save_as(m, "Mine")
    t.eq(#m.toasts, 1)
    t.ok(m.toasts[1].text:find(text, 1, true), m.toasts[1].text)
    t.eq(#m.registered.presets, 3)
    t.eq(find(m, "name").text, "Mine", "editor state kept")
  end
end)

t.case("German texts for the editor toasts and own preset hint", function()
  local m = mock.load_bundle({ language = "de", store = { presets = { entry(1, "Meins") } } })
  t.eq(m.registered.presets[4].hint, "Dein eigenes Preset")
  save_as(m, "Neu")
  t.eq(m.toasts[1].title, "Preset gespeichert")
end)

t.case("registration of the games and built-ins is unchanged", function()
  local m = mock.load_bundle()
  t.eq(m.registered.engine, "randomizer")
  t.eq(#m.registered.presets, 3)
  t.ok(#m.registered.games >= 5)
end)

t.case("save changes after another PC changed the open preset writes nothing", function()
  local m = mock.load_bundle({ store = { presets = { entry(1, "Mine") } } })
  m.action("load_own", "own-1")
  m.action("set:race_mode", true)
  local other = entry(1, "Mine")
  other.settings = fvx.encode((function() local o = fvx.defaults(); o.bst_mod = "random"; return o end)())
  m.external_write("presets", { other }, true)
  local puts, calls, string_before = m.store_puts, m.register_calls, find(m, "string").value
  m.action("save_changes")
  t.eq(m.store_puts, puts)
  t.eq(m.store_data.presets.value[1].settings, other.settings)
  t.eq(toast_titles(m), { "Presets changed" })
  t.ok(m.toasts[1].text:find("changed on another PC", 1, true))
  t.eq(find(m, "string").value, string_before, "editor state kept")
  t.eq(m.register_calls, calls)
  -- deleting is refused the same way; the preset can still be saved as a new one
  m.action("delete")
  t.eq(m.store_puts, puts)
  m.action("save_new")
  t.eq(#m.store_data.presets.value, 2)
end)

t.case("save changes after another PC deleted the open preset writes nothing", function()
  local m = mock.load_bundle({ store = { presets = { entry(1, "Mine") } } })
  m.action("load_own", "own-1")
  m.external_write("presets", {}, true)
  m.action("name", "Still here")
  m.action("save_new")
  t.eq(#m.store_data.presets.value, 1)
  t.eq(m.store_data.presets.value[1].name, "Still here")
end)

t.case("a successful save updates the snapshot", function()
  local m = mock.load_bundle({ store = { presets = { entry(1, "Mine") } } })
  m.action("load_own", "own-1")
  m.action("set:race_mode", true)
  m.action("save_changes")
  m.action("set:race_mode", false)
  m.action("save_changes")
  t.eq(m.store_data.presets.value[1].settings, entry(1).settings)
  t.eq(#m.toasts, 2)
end)
