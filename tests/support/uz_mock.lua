-- Fake `uz` for tests: i18n from plugin/i18n, events, uz.ui (validated), and the contract of uz.variants.
local validator = require("ui_validator")
local M = {}

local function read_file(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end
M.read_file = read_file

--- Reader for flat JSON objects with string values (i18n files).
function M.read_json_flat(s)
  local out = {}
  local esc = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
  local pos = 1
  while true do
    local k, e = s:match('^%s*[{,]?%s*"([^"]*)"%s*:%s*()', pos)
    if not k then break end
    pos = e
    assert(s:sub(pos, pos) == '"', "flat string values only")
    pos = pos + 1
    local buf = {}
    while true do
      local c = s:sub(pos, pos)
      if c == "" then error("unterminated string") end
      if c == '"' then pos = pos + 1; break end
      if c == "\\" then
        local n = s:sub(pos + 1, pos + 1)
        if n == "u" then
          buf[#buf + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16))
          pos = pos + 6
        else
          buf[#buf + 1] = assert(esc[n], "bad escape")
          pos = pos + 2
        end
      else
        buf[#buf + 1] = c
        pos = pos + 1
      end
    end
    out[k] = table.concat(buf)
  end
  return out
end

local function deep_copy(v)
  if type(v) ~= "table" then return v end
  local c = {}
  for k, x in pairs(v) do c[k] = deep_copy(x) end
  return c
end

-- opts: store (initial data { key = value }), no_store (older app without uz.store), store_put_error (code for every put), store_get_error (get raises), variants_list, engine, no_list, no_engine, list_error (see uz.variants below), language ("en"/"de"), permissions (set; default ui + variants.build + store), register_error (string).
function M.new(opts)
  opts = opts or {}
  local perms = opts.permissions or { ui = true, ["variants.build"] = true, store = true }
  local mock = { logs = {}, handlers = {}, trees = {}, registered = {}, register_calls = 0, opened = {}, toasts = {},
    store_data = {}, store_conflicts = {}, store_puts = 0 }
  local uz = { api = 1, plugin = { id = "uzume.randomizer", version = "0.3.0" }, game = {} }
  if opts.language then uz.game.language = opts.language end
  mock.uz = uz

  local en = M.read_json_flat(read_file("plugin/i18n/en.json"))
  local lang = opts.language and M.read_json_flat(read_file("plugin/i18n/" .. opts.language .. ".json")) or {}
  uz.i18n = {
    t = function(key, vars)
      local s = lang[key] or en[key] or key
      return (s:gsub("{(%w+)}", function(name) return vars and vars[name] ~= nil and tostring(vars[name]) or nil end))
    end,
  }

  local function log(level)
    return function(...)
      local parts = {}
      for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
      mock.logs[#mock.logs + 1] = { level = level, text = table.concat(parts, "\t") }
    end
  end
  uz.log = { debug = log("debug"), info = log("info"), warn = log("warn"), error = log("error") }

  uz.events = {
    on = function(plugin_id, name, fn)
      mock.handlers[plugin_id .. ":" .. name] = fn
    end,
  }
  --- Deliver a host event: mock.fire("detail.game", { system = ..., code = ..., title = ... }).
  function mock.fire(name, value, source)
    source = source or "uz"
    local fn = mock.handlers[source .. ":" .. name]
    if fn then fn(deep_copy(value), source, name) end
  end

  local function need(p)
    if not perms[p] then error("permission " .. p .. " not granted", 3) end
  end

  local function checked(slot, tree)
    assert(slot == "detail" or slot == "screen", "slot " .. tostring(slot) .. " not declared in manifest")
    local ok, err = validator.validate(tree)
    if not ok then error("ui tree: " .. tostring(err), 3) end
    mock.last_count = validator.last_count()
  end

  uz.ui = {
    set = function(slot, tree)
      need("ui")
      checked(slot, tree)
      mock.trees[slot] = deep_copy(tree)
    end,
    clear = function(slot)
      need("ui")
      mock.trees[slot] = nil
    end,
    patch = function(slot, id, props)
      need("ui")
      local tree = mock.trees[slot]
      if not tree then error("no tree in slot " .. slot, 2) end
      local block = validator.find(tree, id)
      if not block then error("unknown id " .. tostring(id), 2) end
      local copy = deep_copy(tree)
      for k, v in pairs(props) do validator.find(copy, id)[k] = v end
      checked(slot, copy)
      mock.trees[slot] = copy
    end,
    open = function(slot)
      need("ui")
      assert(slot == "screen" or slot == "panel", "uz.ui.open only supports the slots screen and panel")
      mock.opened[#mock.opened + 1] = slot
    end,
    notify = function(spec)
      need("ui")
      assert(type(spec.text) == "string" and #spec.text >= 1 and #spec.text <= 300, "toast text 1 to 300 characters")
      assert(spec.title == nil or #spec.title <= 80, "toast title")
      mock.toasts[#mock.toasts + 1] = deep_copy(spec)
      return #mock.toasts
    end,
    on_action = function(fn)
      need("ui")
      mock.action_handler = fn
    end,
  }
  --- Deliver a UI action as the app would: mock.action("set:race_mode", true, "screen").
  function mock.action(name, value, slot)
    assert(mock.action_handler, "no action handler")
    mock.action_handler(name, deep_copy(value), slot or "screen")
  end

  -- uz.store with revisions. A put with a stale base_revision is refused and kept as a conflict copy.
  if not opts.no_store then
    for k, v in pairs(opts.store or {}) do mock.store_data[k] = { value = deep_copy(v), rev = 1 } end
    uz.store = {
      get = function(key)
        need("store")
        if opts.store_get_error then error(opts.store_get_error, 2) end
        local e = mock.store_data[key]
        if not e then return nil, 0 end
        return deep_copy(e.value), e.rev
      end,
      put = function(key, value, base)
        need("store")
        mock.store_puts = mock.store_puts + 1
        if opts.store_put_error then return nil, opts.store_put_error end
        local e = mock.store_data[key]
        local rev = e and e.rev or 0
        if base ~= nil and base ~= rev then
          mock.store_conflicts[key] = mock.store_conflicts[key] or {}
          table.insert(mock.store_conflicts[key], { value = deep_copy(value), revision = rev, source = "local" })
          return nil, "conflict"
        end
        mock.store_data[key] = { value = deep_copy(value), rev = rev + 1 }
        mock.store_conflicts[key] = nil
        return true, rev + 1
      end,
      conflicts = function(key)
        need("store")
        return deep_copy(mock.store_conflicts[key] or {})
      end,
    }
  end
  --- Another PC wrote the key: bumps the revision. Pass fire = true to deliver the app event store.changed.
  function mock.external_write(key, value, fire)
    local e = mock.store_data[key]
    mock.store_data[key] = { value = deep_copy(value), rev = (e and e.rev or 0) + 1 }
    if fire then mock.fire("store.changed", key, "app") end
  end

  uz.variants = {
    register = function(spec)
      need("variants.build")
      mock.register_calls = mock.register_calls + 1
      if opts.register_error then error(opts.register_error, 2) end
      assert(spec.engine == "randomizer", "engine")
      for _, p in ipairs(spec.presets) do
        assert(type(p.id) == "string" and type(p.label) == "string" and type(p.hint) == "string", "preset fields")
        assert(type(p.settings) == "table" and next(p.settings), "preset settings")
      end
      mock.registered = deep_copy(spec)
      return true
    end,
    list = function(game_id)
      need("variants.build")
      mock.list_calls = (mock.list_calls or 0) + 1
      mock.list_game_id = game_id
      if game_id == nil then return {} end -- shell context contract: no game id, no list
      return opts.variants_list or {}
    end,
    engine = function()
      need("variants.build")
      return opts.engine or { offered = true, version = "1.6.2", on_pc = false }
    end,
  }
  -- Older apps: opts.no_list / opts.no_engine remove the function; opts.list_error makes list raise.
  if opts.no_list then uz.variants.list = nil end
  if opts.no_engine then uz.variants.engine = nil end
  if opts.list_error then uz.variants.list = function() error("no_game", 2) end end

  return mock
end

--- Loads the bundled plugin/main.lua into a fresh mock (global `uz` only during the load).
function M.load_bundle(opts)
  local m = M.new(opts)
  _G.uz = m.uz
  local chunk = assert(loadfile("plugin/main.lua"))
  local ok, err = pcall(chunk)
  _G.uz = nil
  assert(ok, err)
  return m
end

return M
