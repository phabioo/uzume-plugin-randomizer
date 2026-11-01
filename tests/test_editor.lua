local t = require("t")
local mock = require("uz_mock")
local validator = require("ui_validator")
local fvx = require("fvx_settings")
local editor = require("editor")
local presets = require("presets")

local en = mock.read_json_flat(mock.read_file("plugin/i18n/en.json"))
local de = mock.read_json_flat(mock.read_file("plugin/i18n/de.json"))
local function tr(tbl) return function(k, vars)
  return ((tbl[k] or k):gsub("{(%w+)}", function(n) return vars and vars[n] ~= nil and tostring(vars[n]) or nil end))
end end

local function screen(m) return m.trees.screen end
local function find(m, id) return validator.find(screen(m), id) end
local function string_of(m) return find(m, "string").value end

local function expected(changes)
  local o = fvx.defaults()
  for k, v in pairs(changes) do o[k] = v end
  return fvx.encode(o)
end

t.case("every schema option sits in exactly one tab and has a label in en and de", function()
  local seen = {}
  for gi, g in ipairs(fvx.groups) do
    t.ok(en["group_" .. g.id] and de["group_" .. g.id], "tab label " .. g.id)
    for _, o in ipairs(g.options) do
      t.ok(not seen[o.id], "option twice: " .. o.id)
      seen[o.id] = gi
      t.ok(en["opt_" .. o.id] and de["opt_" .. o.id], "label " .. o.id)
      for _, c in ipairs(o.choices or {}) do
        for _, lang in ipairs({ en, de }) do
          local found = false
          for _, k in ipairs(editor.choice_keys(o, c)) do if lang[k] then found = true end end
          t.ok(found, "choice label " .. o.id .. "/" .. c)
        end
      end
    end
  end
  t.ok(next(seen) ~= nil)
end)

t.case("section headings point at real options and have texts", function()
  for id, sec in pairs(editor.SECTIONS) do
    t.ok(fvx.by_id[id], "unknown option " .. id)
    t.ok(en["sec_" .. sec] and de["sec_" .. sec], "heading " .. sec)
  end
end)

t.case("labels are German in German and differ from English where words differ", function()
  t.eq(de.opt_abilities_mod, "Fähigkeiten")
  t.eq(de.group_moves_movesets, "Attacken")
  t.eq(de.group_trainers, "Trainer")
  t.eq(de.group_wild, "Wilde Pokémon")
  t.eq(de.group_tms_tutors, "TMs & Lehrer")
  t.eq(de.opt_base_stats_mod, "Basiswerte")
end)

t.case("every tab validates and stays far below the block limit", function()
  local m = mock.new()
  local tt = m.uz.i18n.t
  local state = editor.new_state()
  for i = 1, #fvx.groups do
    state.tab = i
    local tree = editor.build(tt, state, { builtins = { { id = "classic", label = "Classic" } }, own = {}, can_save = true })
    local ok, err = validator.validate(tree)
    t.ok(ok, "tab " .. i .. ": " .. tostring(err))
    t.ok(validator.last_count() < 400, "tab " .. i .. " has " .. validator.last_count() .. " blocks")
    -- every option of this tab is in the tree, once
    for _, o in ipairs(fvx.groups[i].options) do
      t.ok(validator.find(tree, "o_" .. o.id), "block for " .. o.id)
    end
  end
end)

t.case("every tab validates with all options switched on and in German", function()
  local m = mock.new({ language = "de" })
  local state = editor.new_state()
  for _, g in ipairs(fvx.groups) do
    for _, o in ipairs(g.options) do
      if o.kind == "bool" then state.opts[o.id] = true end
      if o.kind == "enum" then state.opts[o.id] = o.choices[#o.choices] end
      if o.kind == "int" then state.opts[o.id] = o.max end
    end
  end
  for i = 1, #fvx.groups do
    state.tab = i
    local ok, err = validator.validate(editor.build(m.uz.i18n.t, state, { can_save = false }))
    t.ok(ok, "tab " .. i .. ": " .. tostring(err))
  end
end)

t.case("int selects offer at most 100 values and always the current one", function()
  for _, g in ipairs(fvx.groups) do
    for _, o in ipairs(g.options) do
      if o.kind == "int" and not editor.is_text_int(o) then
        for _, cur in ipairs({ o.default, o.min, o.max }) do
          local vals = editor.int_values(o, cur)
          t.ok(#vals <= 100 and #vals >= 1, o.id .. " has " .. #vals)
          local has = false
          for _, v in ipairs(vals) do if v == cur then has = true end end
          t.ok(has, o.id .. " lacks " .. cur)
        end
      end
    end
  end
end)

t.case("the screen is set at load, with the first tab and the string of the defaults", function()
  local m = mock.load_bundle()
  t.ok(screen(m))
  t.eq(find(m, "tabs").selected, 1)
  t.eq(#find(m, "tabs").tabs, #fvx.groups)
  t.eq(string_of(m), fvx.encode(fvx.defaults()))
  t.ok(find(m, "o_base_stats_mod"))
  t.ok(not find(m, "o_trainers_mod"), "other tabs are empty")
end)

t.case("selecting an option changes the string", function()
  local m = mock.load_bundle()
  m.action("set:base_stats_mod", "random")
  t.eq(string_of(m), expected({ base_stats_mod = "random" }))
  t.eq(find(m, "o_base_stats_mod").selected, "random")
end)

t.case("toggling changes the string (also for an option on another tab)", function()
  local m = mock.load_bundle()
  m.action("set:race_mode", true)
  t.eq(string_of(m), expected({ race_mode = true }))
  m.action("tab", 8)
  t.eq(find(m, "o_race_mode").checked, true)
  m.action("set:race_mode", false)
  t.eq(string_of(m), expected({}))
end)

t.case("numbers: levels and percents, floats from older apps are accepted", function()
  local m = mock.load_bundle()
  m.action("set:wild_level_modifier", 15.0)
  m.action("set:tms_good_damaging_percent", 40.0)
  t.eq(string_of(m), expected({ wild_level_modifier = 15, tms_good_damaging_percent = 40 }))
  m.action("tab", 5)
  t.eq(find(m, "o_wild_level_modifier").selected, 15)
  local labels = {}
  for _, o in ipairs(find(m, "o_wild_level_modifier").options) do labels[o.value] = o.label end
  t.eq(labels[15], "+15 %")
  t.eq(labels[-10], "-10 %")
  t.eq(labels[0], "0 %")
end)

t.case("tabs switch and render only the selected page", function()
  local m = mock.load_bundle()
  m.action("tab", 4)
  t.eq(find(m, "tabs").selected, 4)
  t.ok(find(m, "o_trainers_mod"))
  t.ok(not find(m, "o_base_stats_mod"))
  m.action("tab", 99.0)
  t.eq(find(m, "tabs").selected, 1)
end)

t.case("options whose requirement is not met are disabled", function()
  local m = mock.load_bundle()
  t.eq(find(m, "o_base_stats_follow_evolutions").disabled, true)
  t.eq(find(m, "o_exp_curve_mod").disabled, true)
  t.eq(find(m, "o_exp_curve_mod").type, "select", "enums with a requirement are selects (segmented has no disabled)")
  m.action("set:base_stats_mod", "random")
  t.eq(find(m, "o_base_stats_follow_evolutions").disabled, false)
  t.eq(find(m, "o_exp_curve_mod").disabled, true)
  m.action("set:standardize_exp_curves", true)
  t.eq(find(m, "o_exp_curve_mod").disabled, false)
end)

t.case("two or three plain choices are segmented, more are a select", function()
  local m = mock.load_bundle()
  t.eq(find(m, "o_base_stats_mod").type, "segmented")
  t.eq(find(m, "o_type_effectiveness_mod").type, "select")
  m.action("tab", 4)
  t.eq(find(m, "o_trainers_mod").type, "select")
end)

t.case("generation hints under options that only apply to some games", function()
  local m = mock.load_bundle()
  local found
  for _, c in ipairs(validator.all(screen(m), "text")) do if c.text == "Only Gen 6-7" then found = true end end
  t.ok(found, "Only Gen 6-7")
  t.eq(editor.gens_text({ 2, 3, 4, 5 }), "2-5")
  t.eq(editor.gens_text({ 3, 5 }), "3, 5")
  t.eq(editor.gens_text({ 7 }), "7")
end)

t.case("pasting a valid string loads it", function()
  local m = mock.load_bundle()
  local s = expected({ race_mode = true, bst_mod = "shuffle", wild_level_modifier = -20 })
  m.action("string", s)
  t.eq(string_of(m), s)
  t.eq(find(m, "string").error, nil)
  m.action("tab", 8)
  t.eq(find(m, "o_race_mode").checked, true)
  m.action("tab", 1)
  t.eq(find(m, "o_bst_mod").selected, "shuffle")
end)

t.case("pasting a string with spaces and line breaks works", function()
  local m = mock.load_bundle()
  local s = expected({ race_mode = true })
  m.action("string", "  " .. s:sub(1, 30) .. "\n" .. s:sub(31) .. " \n")
  t.eq(string_of(m), s)
end)

t.case("a built-in preset string loads and shows the same string again", function()
  local m = mock.load_bundle()
  for _, id in ipairs(presets.order) do
    m.action("base", "preset:" .. id)
    t.eq(string_of(m), presets.settings[id]["428"], id)
    t.eq(find(m, "base").selected, "preset:" .. id)
  end
  m.action("base", "default")
  t.eq(string_of(m), fvx.encode(fvx.defaults()))
end)

t.case("an invalid string shows the error and keeps the options", function()
  local m = mock.load_bundle()
  m.action("set:race_mode", true)
  local good = string_of(m)
  m.action("string", "not a settings string")
  t.eq(find(m, "string").error, (en.err_bad_version:gsub("{version}", "428")))
  t.eq(find(m, "string").value, "not a settings string")
  m.action("tab", 8)
  t.eq(find(m, "o_race_mode").checked, true)
  -- damaged checksum
  local bad = good:sub(1, -9) .. (good:sub(-8, -8) == "A" and "B" or "A") .. good:sub(-7)
  m.action("string", bad)
  t.ok(find(m, "string").error, "error for a damaged string")
  m.action("string", "")
  t.ok(find(m, "string").error)
  -- a change of an option clears the error and shows the string of the state again
  m.action("set:race_mode", false)
  t.eq(find(m, "string").error, nil)
  t.eq(string_of(m), expected({}))
end)

t.case("error texts exist for every decode code, in English and German", function()
  for _, code in ipairs({ "bad_input", "bad_version", "bad_base64", "bad_length", "bad_checksum", "bad_value" }) do
    t.ok(en["err_" .. code] and de["err_" .. code], code)
  end
  local m = mock.load_bundle({ language = "de" })
  m.action("string", "x")
  t.eq(find(m, "string").error, (de.err_bad_version:gsub("{version}", "428")))
end)

t.case("custom starter numbers: textfield, checked range", function()
  local m = mock.load_bundle()
  m.action("tab", 2)
  t.eq(find(m, "o_custom_starter_1").type, "textfield")
  t.eq(find(m, "o_custom_starter_1").disabled, true)
  m.action("set:starters_mod", "custom")
  t.eq(find(m, "o_custom_starter_1").disabled, false)
  m.action("set:custom_starter_1", "25")
  t.eq(string_of(m), expected({ starters_mod = "custom", custom_starter_1 = 25 }))
  m.action("set:custom_starter_1", "abc")
  t.ok(find(m, "o_custom_starter_1").error)
  t.eq(find(m, "o_custom_starter_1").text, "25")
  m.action("set:custom_starter_1", "70000")
  t.ok(find(m, "o_custom_starter_1").error)
  m.action("set:custom_starter_1", "150")
  t.eq(find(m, "o_custom_starter_1").error, nil)
  t.eq(string_of(m), expected({ starters_mod = "custom", custom_starter_1 = 150 }))
end)

t.case("BST limits offer 'No limit' and steps of 50", function()
  local m = mock.load_bundle()
  m.action("tab", 2)
  local opts = find(m, "o_starters_bst_maximum").options
  t.eq(opts[1].value, 0)
  t.eq(opts[1].label, "No limit")
  t.eq(opts[2].value, 100)
  m.action("set:starters_bst_maximum", 400)
  t.eq(string_of(m), expected({ starters_bst_maximum = 400 }))
end)

t.case("unknown options and bad values are ignored", function()
  local m = mock.load_bundle()
  local before = string_of(m)
  m.action("set:no_such_option", true)
  m.action("set:base_stats_mod", "nonsense")
  m.action("set:race_mode", "yes")
  m.action("tab", 8)
  t.eq(string_of(m), before)
end)

t.case("German UI: tab labels, option labels and choices", function()
  local m = mock.load_bundle({ language = "de" })
  t.eq(find(m, "tabs").tabs[3], "Attacken")
  t.eq(find(m, "o_base_stats_mod").options[2].label, "Mischen")
  m.action("tab", 5)
  t.eq(find(m, "o_wild_zone_mod").options[5].label, "Im ganzen Spiel")
end)

t.case("the detail card of a supported game opens the screen", function()
  local m = mock.load_bundle()
  m.fire("detail.game", { system = "nds", code = "IPKE", title = "Coral Saga: Ember" })
  local btn = validator.find(m.trees.detail, "edit_options")
  t.ok(btn, "button")
  t.eq(btn.variant, "secondary")
  t.eq(btn.label, "Edit options…")
  m.action(btn.action, nil, "detail")
  t.eq(m.opened, { "screen" })
end)

t.case("an unsupported game has no editor button", function()
  local m = mock.load_bundle()
  m.fire("detail.game", { system = "nds", code = "ZZZZ", title = "Meadow Courier" })
  t.ok(not validator.find(m.trees.detail, "edit_options"))
end)

t.case("without uz.store the editor still works and says why saving is missing", function()
  local m = mock.load_bundle({ no_store = true })
  t.ok(not find(m, "save"), "no save button")
  local note
  for _, x in ipairs(validator.all(screen(m), "text")) do if x.text:find("can't save presets", 1, true) then note = true end end
  t.ok(note, "note")
  m.action("set:race_mode", true)
  t.eq(string_of(m), expected({ race_mode = true }))
  t.eq(m.register_calls, 1)
  t.eq(#m.registered.presets, 3)
end)
