-- The person's own presets: kept in uz.store under the key "presets" (array of { id, name, settings }) and
-- handed to Uzume together with the built-in presets by uz.variants.register.
-- Every write carries the revision that was read; a stale write is refused (never overwritten silently).
local M = {}

M.KEY = "presets"
M.MAX = 29 -- 3 built-in presets + 29 of their own = the 32 Uzume accepts

local Own = {}
Own.__index = Own

--- env = { store = uz.store | nil, variants = uz.variants, builtin = fn() -> presets, games = fn() -> games,
---         hint = text, register_failed = fn(error) -> text, log = fn(level, text) }
function M.new(env)
  return setmetatable({ env = env, list = {}, revision = 0 }, Own)
end

local function log(self, level, text)
  if self.env.log then self.env.log(level, text) end
end

local function clean(entry)
  if type(entry) ~= "table" then return nil end
  local id, name, settings = entry.id, entry.name, entry.settings
  if type(id) ~= "string" or not id:match("^own%-%d+$") or #id > 32 then return nil end
  if type(name) ~= "string" or name == "" or (utf8.len(name) or 61) > 60 then return nil end
  if type(settings) ~= "string" or #settings > 4096 or not settings:match("^%d%d%d[A-Za-z0-9+/=]+$") then return nil end
  return { id = id, name = name, settings = settings }
end

--- Can presets be saved (older apps have no uz.store)?
function Own:available()
  local s = self.env.store
  return type(s) == "table" and type(s.get) == "function" and type(s.put) == "function"
end

--- Reads the list from the store. Returns true, or nil and a message (the list is then empty).
function Own:reload()
  self.list, self.revision = {}, 0
  if not self:available() then return nil, "no_store" end
  local ok, value, rev = pcall(self.env.store.get, M.KEY)
  if not ok then
    log(self, "error", tostring(value))
    return nil, "failed"
  end
  self.revision = math.tointeger(rev) or 0
  if type(value) == "table" then
    for _, entry in ipairs(value) do
      local e = clean(entry)
      if e and #self.list < M.MAX then self.list[#self.list + 1] = e end
    end
  end
  return true
end

function Own:find(id)
  for _, p in ipairs(self.list) do if p.id == id then return p end end
end

--- Registers the built-in presets and the own ones with the games. Returns true, or nil and the error text.
function Own:register()
  local presets = {}
  for _, p in ipairs(self.env.builtin()) do presets[#presets + 1] = p end
  for _, p in ipairs(self.list) do
    presets[#presets + 1] = { id = p.id, label = p.name, hint = self.env.hint, settings = { [p.settings:sub(1, 3)] = p.settings } }
  end
  local ok, err = pcall(self.env.variants.register, { engine = "randomizer", presets = presets, games = self.env.games() })
  if not ok then
    log(self, "error", self.env.register_failed and self.env.register_failed(tostring(err)) or tostring(err))
    return nil, tostring(err)
  end
  return true
end

local function copy(list)
  local out = {}
  for i, p in ipairs(list) do out[i] = { id = p.id, name = p.name, settings = p.settings } end
  return out
end

-- Writes `list` with the revision that was read. On success the list is adopted and registered; a conflict
-- reloads the store (the attempted version stays as a conflict copy in uz.store) and registers again.
function Own:write(list)
  if not self:available() then return nil, "no_store" end
  local ok, a, b = pcall(self.env.store.put, M.KEY, list, self.revision)
  if not ok then
    log(self, "error", tostring(a))
    return nil, "failed"
  end
  if a == true then
    self.list, self.revision = list, math.tointeger(b) or self.revision
    self:register()
    return true
  end
  if b == "conflict" then
    self:reload()
    self:register()
    return nil, "conflict"
  end
  if b == "too_large" or b == "quota_exceeded" then return nil, b end
  return nil, "failed"
end

local function next_id(list)
  local max = 0
  for _, p in ipairs(list) do
    local n = tonumber(p.id:match("^own%-(%d+)$"))
    if n and n > max then max = n end
  end
  return "own-" .. (max + 1)
end

--- Adds a preset. Returns its id, or nil and "limit", "no_store", "conflict", "too_large", "quota_exceeded", "failed".
function Own:add(name, settings)
  if #self.list >= M.MAX then return nil, "limit" end
  local list = copy(self.list)
  local id = next_id(list)
  list[#list + 1] = { id = id, name = name, settings = settings }
  local ok, code = self:write(list)
  if not ok then return nil, code end
  return id
end

--- Replaces name and settings of an own preset. Returns true, or nil and a code ("not_found" included).
function Own:update(id, name, settings)
  if not self:find(id) then return nil, "not_found" end
  local list = copy(self.list)
  for _, p in ipairs(list) do
    if p.id == id then p.name, p.settings = name, settings end
  end
  return self:write(list)
end

function Own:remove(id)
  if not self:find(id) then return nil, "not_found" end
  local list = {}
  for _, p in ipairs(self.list) do
    if p.id ~= id then list[#list + 1] = { id = p.id, name = p.name, settings = p.settings } end
  end
  return self:write(list)
end

return M
