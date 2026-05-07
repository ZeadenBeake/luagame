local h = require "tests.helpers"
local registry = require "engine.registry"

local T = {}

function T.add_and_lookup()
  local r = registry.new()
  registry.addItem(r, { id = "torch", name = "torch" })
  h.assertEq(r.items.torch.name, "torch")
end

function T.duplicate_id_errors()
  local r = registry.new()
  registry.addRoom(r, { id = "x", name = "X" })
  h.assertThrows(function() registry.addRoom(r, { id = "x", name = "Y" }) end, "duplicate")
end

function T.requires_string_id()
  local r = registry.new()
  h.assertThrows(function() registry.addItem(r, {}) end, "id")
  h.assertThrows(function() registry.addItem(r, { id = "" }) end, "id")
end

function T.load_data_file()
  local r = registry.new()
  registry.loadDataFile(r, "examples/cave/data/items.lua", "item")
  h.assertEq(r.items.lantern.name, "brass lantern")
  h.assertEq(r.items.boulder.takeable, false)
end

return T
