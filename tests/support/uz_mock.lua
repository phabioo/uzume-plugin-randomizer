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

-- opts: language ("en"/"de"), permissions (set; default ui + variants.build), register_error (string).
function M.new(opts)
  opts = opts or {}
  local perms = opts.permissions or { ui = true, ["variants.build"] = true }
  local mock = { logs = {}, handlers = {}, trees = {}, registered = {}, register_calls = 0 }
  local uz = { api = 1, plugin = { id = "uzume.randomizer", version = "0.1.1" }, game = {} }
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

  uz.ui = {
    set = function(slot, tree)
      need("ui")
      assert(slot == "detail", "slot " .. tostring(slot) .. " not declared in manifest")
      local ok, err = validator.validate(tree)
      if not ok then error("ui tree: " .. tostring(err), 2) end
      mock.trees[slot] = deep_copy(tree)
    end,
    clear = function(slot)
      need("ui")
      mock.trees[slot] = nil
    end,
  }

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
    list = function() need("variants.build"); return {} end,
    engine = function() need("variants.build"); return { offered = true, version = "1.6.2", on_pc = false } end,
  }

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
