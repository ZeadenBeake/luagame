local h = require "tests.helpers"
local state = require "engine.state"

local T = {}

function T.place_and_list()
  local s = state.new()
  state.placeItem(s, "r1", "a")
  state.placeItem(s, "r1", "b")
  local items = state.itemsInRoom(s, "r1")
  h.assertEq(#items, 2)
end

function T.take_drop_cycle()
  local s = state.new()
  state.placeItem(s, "r1", "a")
  h.assertTrue(state.removeItemFromRoom(s, "r1", "a"))
  state.addToInventory(s, "a")
  h.assertTrue(state.hasItem(s, "a"))
  state.removeFromInventory(s, "a")
  h.assertEq(state.hasItem(s, "a"), false)
end

function T.snapshot_is_independent()
  local s = state.new()
  s.currentRoom = "r1"
  state.placeItem(s, "r1", "a")
  state.addToInventory(s, "b")
  s.flags.opened = true
  local snap = state.snapshot(s)
  state.removeFromInventory(s, "b")
  s.flags.opened = false
  h.assertEq(snap.flags.opened, true)
  h.assertEq(snap.inventory[1], "b")
end

function T.restore_overwrites()
  local s = state.new()
  s.currentRoom = "r1"
  state.addToInventory(s, "a")
  local snap = state.snapshot(s)
  state.addToInventory(s, "b")
  s.currentRoom = "r2"
  state.restore(s, snap)
  h.assertEq(s.currentRoom, "r1")
  h.assertEq(#s.inventory, 1)
  h.assertEq(s.inventory[1], "a")
end

return T
