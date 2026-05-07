local M = {}

function M.new()
  return {
    currentRoom = nil,
    inventory = {},
    roomItems = {},
    flags = {},
  }
end

function M.placeItem(state, roomId, itemId)
  state.roomItems[roomId] = state.roomItems[roomId] or {}
  table.insert(state.roomItems[roomId], itemId)
end

function M.removeItemFromRoom(state, roomId, itemId)
  local list = state.roomItems[roomId]
  if not list then return false end
  for i, id in ipairs(list) do
    if id == itemId then table.remove(list, i); return true end
  end
  return false
end

function M.addToInventory(state, itemId)
  table.insert(state.inventory, itemId)
end

function M.removeFromInventory(state, itemId)
  for i, id in ipairs(state.inventory) do
    if id == itemId then table.remove(state.inventory, i); return true end
  end
  return false
end

function M.hasItem(state, itemId)
  for _, id in ipairs(state.inventory) do
    if id == itemId then return true end
  end
  return false
end

function M.itemsInRoom(state, roomId)
  return state.roomItems[roomId] or {}
end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

function M.snapshot(state) return deepcopy(state) end

function M.restore(state, snap)
  for k in pairs(state) do state[k] = nil end
  for k, v in pairs(deepcopy(snap)) do state[k] = v end
end

return M
