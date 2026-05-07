local h = require "tests.helpers"
local state = require "engine.state"
local party = require "engine.party"
local character = require "engine.character"

local T = {}

function T.new_has_party_and_world_tables()
  local s = state.new()
  h.assertTrue(s.party)
  h.assertTrue(s.roomItems)
  h.assertTrue(s.flags)
end

function T.place_and_list_room_items()
  local s = state.new()
  state.placeItem(s, "r1", "a")
  state.placeItem(s, "r1", "b")
  h.assertEq(#state.itemsInRoom(s, "r1"), 2)
end

function T.remove_item_from_room()
  local s = state.new()
  state.placeItem(s, "r1", "a")
  h.assertTrue(state.removeItemFromRoom(s, "r1", "a"))
  h.assertEq(state.removeItemFromRoom(s, "r1", "a"), false)
end

function T.snapshot_restore_round_trip()
  local s = state.new()
  party.add(s.party, { id = "rin", name = "Rin" })
  s.party.location = "r1"
  state.placeItem(s, "r2", "key")
  character.addItem(party.active(s.party), "lantern")
  s.flags.opened = true

  local snap = state.snapshot(s)

  s.party.location = "r2"
  s.flags.opened = false
  character.removeItem(party.active(s.party), "lantern")
  state.removeItemFromRoom(s, "r2", "key")

  state.restore(s, snap)

  h.assertEq(s.party.location, "r1")
  h.assertEq(s.flags.opened, true)
  h.assertTrue(character.hasItem(party.active(s.party), "lantern"))
  h.assertEq(state.itemsInRoom(s, "r2")[1], "key")
end

function T.snapshot_is_independent()
  local s = state.new()
  party.add(s.party, { id = "rin" })
  character.addItem(party.active(s.party), "lantern")
  local snap = state.snapshot(s)
  character.removeItem(party.active(s.party), "lantern")
  h.assertEq(snap.party.characters.rin.inventory[1], "lantern")
end

return T
