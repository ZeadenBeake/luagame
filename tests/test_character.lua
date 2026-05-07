local h = require "tests.helpers"
local character = require "engine.character"

local T = {}

function T.new_requires_id()
  h.assertThrows(function() character.new({}) end, "id")
  h.assertThrows(function() character.new({ id = "" }) end, "id")
end

function T.new_defaults_name_to_id()
  local c = character.new({ id = "rin" })
  h.assertEq(c.name, "rin")
end

function T.new_uses_explicit_name()
  local c = character.new({ id = "rin", name = "Rin the Swift" })
  h.assertEq(c.name, "Rin the Swift")
end

function T.inventory_round_trip()
  local c = character.new({ id = "rin" })
  character.addItem(c, "lantern")
  h.assertTrue(character.hasItem(c, "lantern"))
  h.assertTrue(character.removeItem(c, "lantern"))
  h.assertEq(character.hasItem(c, "lantern"), false)
end

function T.remove_missing_returns_false()
  local c = character.new({ id = "rin" })
  h.assertEq(character.removeItem(c, "ghost"), false)
end

return T
