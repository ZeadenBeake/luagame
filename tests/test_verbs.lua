local h = require "tests.helpers"
local mock = require "tests.cc_mock"
local engine = require "engine"

local function newGame()
  mock.reset()
  local g = engine.new()
  g:loadItems("examples/cave/data/items.lua")
  g:loadCreatures("examples/cave/data/creatures.lua")
  g:loadRooms("examples/cave/data/rooms.lua")
  g:setStart("forest")
  for id, room in pairs(g.registry.rooms) do
    if room.items then
      for _, itemId in ipairs(room.items) do
        engine.state.placeItem(g.state, id, itemId)
      end
    end
  end
  return g
end

local T = {}

function T.look_describes_room()
  local g = newGame()
  mock.clear()
  g:dispatch("look")
  h.assertContains(mock.output(), "Edge of the Forest")
  h.assertContains(mock.output(), "brass lantern")
  h.assertContains(mock.output(), "north")
end

function T.take_moves_item()
  local g = newGame()
  g:dispatch("take lantern")
  h.assertEq(engine.state.hasItem(g.state, "lantern"), true)
  h.assertEq(#engine.state.itemsInRoom(g.state, "forest"), 0)
end

function T.take_uses_alias()
  local g = newGame()
  g:dispatch("take lamp")
  h.assertEq(engine.state.hasItem(g.state, "lantern"), true)
end

function T.take_rejects_untakeable()
  local g = newGame()
  g.state.currentRoom = "cave_entrance"
  mock.clear()
  g:dispatch("take boulder")
  h.assertContains(mock.output(), "can't take")
end

function T.movement_changes_room()
  local g = newGame()
  g:dispatch("north")
  h.assertEq(g.state.currentRoom, "cave_entrance")
  g:dispatch("s")
  h.assertEq(g.state.currentRoom, "forest")
end

function T.movement_blocked_when_no_exit()
  local g = newGame()
  mock.clear()
  g:dispatch("east")
  h.assertContains(mock.output(), "can't go that way")
end

function T.drop_returns_item_to_room()
  local g = newGame()
  g:dispatch("take lantern")
  g:dispatch("north")
  g:dispatch("drop lantern")
  local items = engine.state.itemsInRoom(g.state, "cave_entrance")
  local found = false
  for _, id in ipairs(items) do if id == "lantern" then found = true end end
  h.assertTrue(found, "lantern should be in cave_entrance after drop")
  h.assertEq(engine.state.hasItem(g.state, "lantern"), false)
end

function T.examine_inventory_item()
  local g = newGame()
  g:dispatch("take lantern")
  mock.clear()
  g:dispatch("examine lamp")
  h.assertContains(mock.output(), "warm glow")
end

function T.unknown_word()
  local g = newGame()
  mock.clear()
  g:dispatch("flarp")
  h.assertContains(mock.output(), "flarp")
end

function T.custom_verb()
  local g = newGame()
  local called = false
  g:registerVerb("dance", function() called = true end)
  g:dispatch("dance")
  h.assertEq(called, true)
end

function T.snapshot_round_trip()
  local g = newGame()
  g:dispatch("take lantern")
  g:dispatch("north")
  local snap = g:snapshot()
  g:dispatch("drop lantern")
  g:dispatch("south")
  g:restore(snap)
  h.assertEq(g.state.currentRoom, "cave_entrance")
  h.assertEq(engine.state.hasItem(g.state, "lantern"), true)
end

function T.run_quits_on_quit_verb()
  local g = newGame()
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(g._running, false)
end

return T
