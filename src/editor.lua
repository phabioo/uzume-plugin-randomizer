-- Options editor: the tree of the `screen` slot and the pure state changes behind it (no uz calls here).
-- The option schema comes from fvx_settings.groups; labels come from i18n (group_<id>, opt_<id>, opt_<id>_<choice>).
-- Nothing here shows what was randomized: only the options the person picks.
local fvx = require("fvx_settings")
local presets = require("presets")

local M = {}

M.MAX_NAME = 60

-- Small headings inside a tab, before the option with that id (i18n key sec_<name>).
M.SECTIONS = {
  base_stats_mod = "base_stats", standardize_exp_curves = "exp_curves", bst_mod = "bst",
  species_types_mod = "types", abilities_mod = "abilities", evolutions_mod = "evolutions",
  pokemon_palettes_mod = "palettes", type_effectiveness_mod = "type_chart",
  starters_mod = "starters", static_pokemon_mod = "statics", totem_pokemon_mod = "totems",
  in_game_trades_mod = "trades",
  randomize_move_powers = "move_data", update_moves = "move_updates", movesets_mod = "movesets",
  trainers_mod = "trainer_teams", randomize_trainer_names = "trainer_names",
  trainers_evolve_their_pokemon = "trainer_levels", additional_boss_trainer_pokemon = "trainer_size",
  randomize_held_items_for_boss_trainer_pokemon = "trainer_items", diverse_types_for_boss_trainers = "trainer_types",
  better_boss_trainer_movesets = "trainer_moves", battle_style_mod = "battle_style",
  randomize_wild_pokemon = "wild_species", use_minimum_catch_rate = "wild_catch_rate",
  randomize_wild_pokemon_held_items = "wild_items", wild_levels_modified = "wild_levels",
  tms_mod = "tms", tms_hms_compatibility_mod = "tm_compat", move_tutor_moves_mod = "tutors",
  move_tutors_compatibility_mod = "tutor_compat",
  field_items_mod = "field_items", shop_items_mod = "shops", pickup_items_mod = "pickup",
  randomize_intro_mon = "general", tweak_bw_exp_patch = "tweaks",
  limit_pokemon = "gen_limits", ban_premature_evos = "other_limits",
}

local ERROR_CODES = { bad_input = true, bad_version = true, bad_base64 = true, bad_length = true, bad_checksum = true, bad_value = true }

-- ------------------------------------------------------------------ state

--- Fresh editor state. opts = every option of the settings string; base = what "Start from" shows;
--- editing = id of the own preset being edited (nil = a new one); name = text of the name field.
function M.new_state()
  return { opts = fvx.defaults(), tab = 1, base = "default", editing = nil, name = "",
    string_text = nil, string_error = nil, errors = {} }
end

local function to_int(v)
  if type(v) == "string" then v = tonumber((v:gsub("^%s+", ""):gsub("%s+$", ""))) end
  if type(v) ~= "number" then return nil end
  return math.tointeger(v)
end
M.to_int = to_int

--- Is the `requires` condition of option o met by the current options?
function M.requirement_met(state, o)
  if not o.requires then return true end
  for k, want in pairs(o.requires) do
    if state.opts[k] ~= want then return false end
  end
  return true
end

--- Set one option from an action value. Returns true when the state changed or a field error was set.
function M.set_option(state, id, value)
  local o = fvx.by_id[id]
  if not o then return false end
  if type(value) == "table" and value.checked ~= nil then value = value.checked end
  if o.kind == "bool" then
    if type(value) ~= "boolean" then return false end
    state.opts[id] = value
  elseif o.kind == "enum" then
    local ok = false
    for _, c in ipairs(o.choices) do if c == value then ok = true end end
    if not ok then return false end
    state.opts[id] = value
  else
    local n = to_int(value)
    if not n or n < o.min or n > o.max then
      state.errors[id] = true
      return true
    end
    state.opts[id] = n
  end
  state.errors[id] = nil
  state.string_text, state.string_error = nil, nil
  return true
end

--- Load a settings string into the state. Returns true, or nil and the decode code (state unchanged).
function M.load_settings(state, str)
  local opts, code = fvx.decode(str)
  if not opts then return nil, code end
  state.opts = opts
  state.errors = {}
  state.string_text, state.string_error = nil, nil
  return true
end

--- The textarea changed. Returns "same" (nothing to do), "loaded" or "error" (state.string_error is set,
--- the options stay as they are).
function M.paste(state, text)
  if type(text) ~= "string" then return "same" end
  local s = text:gsub("%s+", "")
  if s == fvx.encode(state.opts) and state.string_error == nil then return "same" end
  local ok, code = M.load_settings(state, s)
  if ok then return "loaded" end
  state.string_text = text
  state.string_error = code
  return "error"
end

--- The settings string of the state.
function M.current_string(state) return fvx.encode(state.opts) end

--- Trimmed preset name, or nil when it is empty or longer than 60 characters.
function M.valid_name(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  local n = utf8.len(name)
  if not n or n < 1 or n > M.MAX_NAME then return nil end
  return name
end

-- ------------------------------------------------------------------ labels and values

--- i18n keys to try, in order, for the label of an enum choice.
function M.choice_keys(o, choice)
  if o.id == "starters_single_type" then return { "type_" .. choice } end
  return { "opt_" .. o.id .. "_" .. choice, "choice_" .. choice }
end

local function choice_label(t, o, choice)
  for _, k in ipairs(M.choice_keys(o, choice)) do
    local s = t(k)
    if s ~= k then return s end
  end
  return choice
end

local function gens_text(gens)
  local parts, i = {}, 1
  while i <= #gens do
    local j = i
    while gens[j + 1] == gens[j] + 1 do j = j + 1 end
    parts[#parts + 1] = j > i and (gens[i] .. "-" .. gens[j]) or tostring(gens[i])
    i = j + 1
  end
  return table.concat(parts, ", ")
end
M.gens_text = gens_text

local function is_level(o) return o.min == -100 and o.max == 155 end
local function is_percent(o) return o.id:find("_percent", 1, true) ~= nil or o.id == "bst_buff_nerf_max_percentage" end
local function is_bst(o) return o.at and (o.at.special == "bst_min" or o.at.special == "bst_max") end
M.is_text_int = function(o) return o.id:match("^custom_starter_%d$") ~= nil end

--- The values and the label function a select offers for an int option. The current value is always included.
function M.int_values(o, current)
  local lo, hi, step = o.ui_min or o.min, o.ui_max or o.max, 1
  local vals, seen = {}, {}
  local function add(v) if not seen[v] then seen[v] = true; vals[#vals + 1] = v end end
  if is_level(o) then
    lo, hi, step = -50, 50, 5
  elseif is_percent(o) then
    step = 5
  elseif is_bst(o) then
    add(0)
    lo, hi, step = 100, 1500, 50
  end
  for v = lo, hi, step do add(v) end
  add(o.default)
  add(current)
  table.sort(vals)
  return vals
end

local function int_label(t, o, v)
  if is_bst(o) and v == 0 then return t("no_limit") end
  if (o.ui_min and o.default < o.ui_min or o.ui_max and o.default > o.ui_max) and v == o.default then return t("not_set") end
  if is_level(o) then return v == 0 and "0 %" or string.format("%+d %%", v) end
  if is_percent(o) then return string.format("%d %%", v) end
  return tostring(v)
end

-- ------------------------------------------------------------------ tree

local function option_block(t, state, o)
  local v = state.opts[o.id]
  local disabled = not M.requirement_met(state, o)
  local bid, action = "o_" .. o.id, "set:" .. o.id
  local label = t("opt_" .. o.id)
  local control

  if o.kind == "bool" then
    control = { type = "toggle", id = bid, action = action, label = label, checked = v == true, disabled = disabled }
  else
    if o.kind == "enum" then
      local options = {}
      for i, c in ipairs(o.choices) do options[i] = { value = c, label = choice_label(t, o, c) } end
      if #options <= 3 and not o.requires then
        control = { type = "segmented", id = bid, action = action, options = options, selected = v }
      else
        control = { type = "select", id = bid, action = action, options = options, selected = v, disabled = disabled }
      end
    elseif M.is_text_int(o) then
      control = { type = "textfield", id = bid, action = action, text = tostring(v), live = true, disabled = disabled,
        error = state.errors[o.id] and t("err_number", { min = o.min, max = o.max }) or nil }
    else
      local options = {}
      for i, n in ipairs(M.int_values(o, v)) do options[i] = { value = n, label = int_label(t, o, n) } end
      control = { type = "select", id = bid, action = action, options = options, selected = v, disabled = disabled }
    end
  end

  local meta = {}
  if M.is_text_int(o) then meta[#meta + 1] = t("number_hint") end
  if o.gens and #o.gens < 7 then meta[#meta + 1] = t("only_gens", { gens = gens_text(o.gens) }) end

  if o.kind == "bool" and #meta == 0 then return control end
  local kids = {}
  if o.kind ~= "bool" then kids[#kids + 1] = { type = "text", text = label, style = "body" } end
  kids[#kids + 1] = control
  for _, m in ipairs(meta) do kids[#kids + 1] = { type = "text", text = m, style = "meta" } end
  return { type = "column", gap = 4, children = kids }
end

local function page(t, state, group)
  local kids = {}
  for _, o in ipairs(group.options) do
    local sec = M.SECTIONS[o.id]
    if sec then kids[#kids + 1] = { type = "text", text = t("sec_" .. sec), style = "eyebrow" } end
    kids[#kids + 1] = option_block(t, state, o)
  end
  return { type = "column", gap = 12, children = kids }
end

--- The tree of one tab page (tests validate each one).
function M.build_page(t, state, index)
  return page(t, state, fvx.groups[index])
end

local function base_options(t, ctx)
  local options = { { value = "default", label = t("start_default") } }
  for _, p in ipairs(ctx.builtins or {}) do options[#options + 1] = { value = "preset:" .. p.id, label = p.label } end
  for _, p in ipairs(ctx.own or {}) do options[#options + 1] = { value = "own:" .. p.id, label = p.name } end
  return options
end

local function save_section(t, state, ctx)
  local kids = {}
  if not ctx.can_save then
    kids[#kids + 1] = { type = "text", text = t("no_store_note"), style = "meta" }
    return { type = "section", title = t("save_title"), children = kids }
  end
  local own_count = #(ctx.own or {})
  local full = own_count >= (ctx.max_own or 29)
  local valid = M.valid_name(state.name) ~= nil
  if state.editing then
    for _, p in ipairs(ctx.own or {}) do
      if p.id == state.editing then kids[#kids + 1] = { type = "text", text = t("editing_note", { name = p.name }), style = "meta" } end
    end
  end
  kids[#kids + 1] = { type = "text", text = t("preset_name"), style = "eyebrow" }
  kids[#kids + 1] = { type = "textfield", id = "name", action = "name", text = state.name, live = true,
    placeholder = t("preset_name_placeholder") }
  local buttons = { { type = "button", id = "save", action = "save_new", label = t("save_new"), variant = "primary",
    disabled = not valid or full } }
  if state.editing then
    buttons[#buttons + 1] = { type = "button", id = "save_changes", action = "save_changes", label = t("save_changes"),
      variant = "secondary", disabled = not valid }
    buttons[#buttons + 1] = { type = "button", id = "delete", action = "delete", label = t("delete_preset"), variant = "danger",
      confirm = { title = t("delete_title"), text = t("delete_text"), confirm_label = t("delete_confirm"), danger = true } }
  end
  kids[#kids + 1] = { type = "row", gap = 8, align = "center", children = buttons }
  if full then kids[#kids + 1] = { type = "text", text = t("limit_note", { n = own_count }), style = "meta" } end
  return { type = "section", title = t("save_title"), children = kids }
end

local function own_section(t, state, ctx)
  local own = ctx.own or {}
  local kids
  if #own == 0 then
    kids = { { type = "text", id = "own_none", text = t("own_none"), style = "meta" } }
  else
    local rows = {}
    for i, p in ipairs(own) do
      rows[i] = { id = p.id, title = p.name, meta = t("own_meta"), action = "load_own", value = p.id }
    end
    kids = { { type = "list", id = "own_list", rows = rows, selected = state.editing } }
  end
  return { type = "section", title = t("own_title"), children = kids }
end

--- The whole `screen` tree. ctx = { builtins = { {id, label} }, own = { {id, name} }, can_save = bool, max_own = 29 }.
function M.build(t, state, ctx)
  ctx = ctx or {}
  local labels, pages = {}, {}
  local tab = math.min(math.max(state.tab or 1, 1), #fvx.groups)
  for i, g in ipairs(fvx.groups) do
    labels[i] = t("group_" .. g.id)
    pages[i] = i == tab and page(t, state, g) or { type = "column", children = {} }
  end
  local base = "default"
  for _, o in ipairs(base_options(t, ctx)) do if o.value == state.base then base = o.value end end
  local err = state.string_error
  local string_text = state.string_text or M.current_string(state)
  return { type = "column", id = "editor", gap = 16, children = {
    { type = "text", id = "note", text = t("editor_note"), style = "meta" },
    { type = "column", gap = 4, children = {
      { type = "text", text = t("start_from"), style = "eyebrow" },
      { type = "select", id = "base", action = "base", options = base_options(t, ctx), selected = base },
    } },
    { type = "tabs", id = "tabs", tabs = labels, selected = tab, action = "tab", children = pages },
    { type = "section", title = t("string_title"), children = {
      { type = "textarea", id = "string", action = "string", value = string_text, lines = 3, mono = true,
        error = err and ERROR_CODES[err] and t("err_" .. err, { version = presets.SETTINGS_VERSION }) or nil },
      { type = "text", text = t("string_hint"), style = "meta" },
    } },
    save_section(t, state, ctx),
    own_section(t, state, ctx),
  } }
end

return M
