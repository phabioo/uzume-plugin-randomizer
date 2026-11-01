-- Entry module of the Randomizer plugin: hands presets (built in and the person's own) and supported games to
-- Uzume (uz.variants.register), shows a status card in the game detail and the options editor on the screen
-- slot. Uzume draws the dialogs, the variant list and the builds.
local presets = require("presets")
local games = require("games")
local card = require("card")
local editor = require("editor")
local own_presets = require("own_presets")

local uz = uz
local t = uz.i18n.t

uz.log.info(t("loaded", { version = (uz.plugin and uz.plugin.version) or "?" }))

local function preset_list()
  local list = {}
  for _, id in ipairs(presets.order) do
    list[#list + 1] = {
      id = id,
      label = t("preset_" .. id .. "_label"),
      hint = t("preset_" .. id .. "_hint"),
      settings = presets.settings[id],
    }
  end
  return list
end

local function game_list()
  local list = {}
  for _, entry in ipairs(games.games) do
    local codes = {}
    for i, c in ipairs(entry.codes) do codes[i] = c end
    list[#list + 1] = { system = entry.system, codes = codes }
  end
  return list
end

-- Host event source: "uz" since Uzume 0.22; older apps only know "fb".
local host = rawget(_ENV, "uz") ~= nil and "uz" or "fb"

local own = own_presets.new({
  store = uz.store,
  variants = uz.variants,
  builtin = preset_list,
  games = game_list,
  hint = t("own_hint"),
  register_failed = function(err) return t("register_failed", { error = err }) end,
  log = function(level, text)
    if level == "error" then uz.log.error(text) else uz.log.warn(text) end
  end,
})

local state = editor.new_state()

local function context()
  local builtins = {}
  for _, id in ipairs(presets.order) do builtins[#builtins + 1] = { id = id, label = t("preset_" .. id .. "_label") } end
  return { builtins = builtins, own = own.list, can_save = own:available(), max_own = own_presets.MAX }
end

local function render()
  local ok, err = pcall(function() uz.ui.set("screen", editor.build(t, state, context())) end)
  if not ok then uz.log.error(tostring(err)) end
end

local function toast(tone, title, text)
  pcall(uz.ui.notify, { tone = tone, title = title, text = text })
end

-- Once at load, also in the shell context (no game running). The built-in presets are registered even when
-- the store cannot be read.
own:reload()
own:register()
render()

-- Variants and engine state for the card. Both calls are optional (older apps, shell context without a game):
-- a missing function or a failed call leaves that part out of the card.
local function card_info(game)
  local info = {}
  local v = uz.variants
  if type(v.engine) == "function" then
    local ok, e = pcall(v.engine)
    if ok and type(e) == "table" then info.engine = e end
  end
  -- The list needs the game id from detail.game (Uzume 22); without it (older apps) the list is left out.
  if type(v.list) == "function" and game.id ~= nil then
    local ok, l = pcall(v.list, game.id)
    if ok and type(l) == "table" then info.variants = l end
  end
  return info
end

local current

local function show()
  if current then uz.ui.set("detail", card.build(t, current, card_info(current))) end
end

uz.events.on(host, "detail.game", function(game)
  if type(game) ~= "table" then
    current = nil
    uz.ui.clear("detail")
    return
  end
  current = game
  show()
end)

-- A build changed state: refresh the card (the event carries no game data we use).
uz.events.on(host, "variants.state", function() pcall(show) end)

-- ---------------------------------------------------------------- options editor

local function forget_missing_preset()
  if state.editing and not own:find(state.editing) then
    state.editing = nil
    state.base = "default"
  end
end

local function load_state_from(settings, base, editing, name)
  local ok = editor.load_settings(state, settings)
  if not ok then return false end
  state.base, state.editing, state.name = base, editing, name or ""
  return true
end

local function pick_base(value)
  if value == "default" then
    local tab = state.tab
    state = editor.new_state()
    state.tab = tab
    return
  end
  local kind, id = tostring(value):match("^(%a+):(.+)$")
  if kind == "preset" and presets.settings[id] then
    load_state_from(presets.settings[id][presets.SETTINGS_VERSION], value, nil, "")
  elseif kind == "own" and own:find(id) then
    local p = own:find(id)
    load_state_from(p.settings, value, id, p.name)
  end
end

local SAVE_ERRORS = {
  conflict = { "warning", "toast_conflict_title", "toast_conflict_text" },
  too_large = { "warning", "toast_failed_title", "toast_too_large" },
  quota_exceeded = { "warning", "toast_failed_title", "toast_quota" },
  limit = { "warning", "toast_failed_title", "toast_limit" },
  no_store = { "warning", "toast_failed_title", "toast_no_store" },
  not_found = { "warning", "toast_failed_title", "toast_gone" },
}

local function save_failed(code)
  local e = SAVE_ERRORS[code] or { "warning", "toast_failed_title", "toast_failed" }
  toast(e[1], t(e[2]), t(e[3]))
  forget_missing_preset()
  render()
end

local function tab_index(value)
  local n = editor.to_int(value)
  return n and n >= 1 and n <= 12 and n or 1
end

local function refresh_save_buttons()
  if not own:available() then return end
  local disabled = editor.valid_name(state.name) == nil
  local ok = pcall(function()
    uz.ui.patch("screen", "save", { disabled = disabled or #own.list >= own_presets.MAX })
    if state.editing then uz.ui.patch("screen", "save_changes", { disabled = disabled }) end
  end)
  if not ok then render() end
end

local function handle(action, value)
  if action == "edit_options" then
    pcall(uz.ui.open, "screen")
  elseif action == "tab" then
    state.tab = tab_index(value)
    render()
  elseif action == "base" then
    pick_base(value)
    render()
  elseif action == "load_own" then
    if own:find(value) then pick_base("own:" .. tostring(value)) end
    render()
  elseif action:sub(1, 4) == "set:" then
    if editor.set_option(state, action:sub(5), value) then render() end
  elseif action == "string" then
    if editor.paste(state, value) ~= "same" then render() end
  elseif action == "name" then
    state.name = type(value) == "string" and value or ""
    refresh_save_buttons()
  elseif action == "save_new" or action == "save_changes" then
    local name = editor.valid_name(state.name)
    if not name or (action == "save_changes" and not state.editing) then return end
    local id, code
    if action == "save_new" then
      id, code = own:add(name, editor.current_string(state))
    elseif state.editing then
      id, code = own:update(state.editing, name, editor.current_string(state))
      if id then id = state.editing end
    end
    if not id then return save_failed(code) end
    state.editing, state.base, state.name = id, "own:" .. id, name
    toast("info", t("toast_saved"), name)
    render()
  elseif action == "delete" then
    if not state.editing then return end
    local gone = own:find(state.editing)
    local ok, code = own:remove(state.editing)
    if not ok then return save_failed(code) end
    state.editing, state.base, state.name = nil, "default", ""
    toast("info", t("toast_deleted"), gone and gone.name or t("own_hint"))
    render()
  end
end

uz.ui.on_action(function(action, value)
  local ok, err = pcall(handle, tostring(action), value)
  if not ok then uz.log.error(tostring(err)) end
end)

-- The store has a newer version of the presets (another PC): read it, register again, keep the editor state.
uz.events.on("app", "store.changed", function(key)
  if key ~= own_presets.KEY then return end
  own:reload()
  own:register()
  forget_missing_preset()
  render()
end)

-- Both versions are kept until the next save: tell the person, never overwrite silently.
uz.events.on("app", "store.conflict", function(key)
  if key ~= own_presets.KEY then return end
  toast("warning", t("toast_conflict_title"), t("toast_conflict_text"))
end)

-- Reloaded plugin: take the presets from the store again.
uz.events.on(host, "reloaded", function()
  own:reload()
  own:register()
  forget_missing_preset()
  render()
end)
