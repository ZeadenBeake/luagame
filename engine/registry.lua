local M = {}

function M.new()
  return { items = {}, creatures = {}, rooms = {} }
end

local function add(tbl, kind, def)
  assert(type(def) == "table", kind .. " def must be a table")
  assert(type(def.id) == "string" and def.id ~= "", kind .. " def must have a non-empty string id")
  assert(not tbl[def.id], "duplicate " .. kind .. " id: " .. def.id)
  tbl[def.id] = def
end

function M.addItem(reg, def) add(reg.items, "item", def) end
function M.addCreature(reg, def) add(reg.creatures, "creature", def) end
function M.addRoom(reg, def) add(reg.rooms, "room", def) end

local kindFn = { item = M.addItem, creature = M.addCreature, room = M.addRoom }

function M.loadDataFile(reg, path, kind)
  local fn = kindFn[kind]
  assert(fn, "unknown kind: " .. tostring(kind))
  local chunk, err = loadfile(path)
  assert(chunk, "failed to load " .. path .. ": " .. tostring(err))
  local data = chunk()
  assert(type(data) == "table", path .. " must return a table")
  for _, def in ipairs(data) do fn(reg, def) end
end

return M
