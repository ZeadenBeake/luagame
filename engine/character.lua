local M = {}

function M.new(def)
  assert(type(def) == "table", "character def must be a table")
  assert(type(def.id) == "string" and def.id ~= "", "character must have a non-empty string id")
  return {
    id = def.id,
    name = def.name or def.id,
    description = def.description,
    inventory = {},
    flags = {},
  }
end

function M.addItem(char, itemId)
  table.insert(char.inventory, itemId)
end

function M.removeItem(char, itemId)
  for i, id in ipairs(char.inventory) do
    if id == itemId then table.remove(char.inventory, i); return true end
  end
  return false
end

function M.hasItem(char, itemId)
  for _, id in ipairs(char.inventory) do
    if id == itemId then return true end
  end
  return false
end

return M
