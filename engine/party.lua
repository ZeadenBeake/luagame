local character = require "engine.character"

local M = {}

function M.new()
  return {
    characters = {},
    order = {},
    active = nil,
    location = nil,
  }
end

function M.add(party, def)
  assert(not party.characters[def.id], "duplicate character id: " .. def.id)
  party.characters[def.id] = character.new(def)
  table.insert(party.order, def.id)
  if not party.active then party.active = def.id end
end

function M.remove(party, id)
  if not party.characters[id] then return false end
  party.characters[id] = nil
  for i, oid in ipairs(party.order) do
    if oid == id then table.remove(party.order, i); break end
  end
  if party.active == id then
    party.active = party.order[1]
  end
  return true
end

function M.setActive(party, id)
  assert(party.characters[id], "unknown character: " .. tostring(id))
  party.active = id
end

function M.active(party)
  return party.active and party.characters[party.active] or nil
end

function M.get(party, id) return party.characters[id] end

function M.list(party)
  local result = {}
  for i, id in ipairs(party.order) do result[i] = party.characters[id] end
  return result
end

function M.resolveByName(party, phrase)
  if type(phrase) ~= "string" or phrase == "" then return nil end
  local lower = phrase:lower()
  for _, id in ipairs(party.order) do
    local char = party.characters[id]
    if char.id:lower() == lower or char.name:lower() == lower then
      return char.id
    end
  end
  return nil
end

return M
