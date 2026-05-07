local h = require "tests.helpers"
local mock = require "tests.cc_mock"
local engine = require "engine"

local function newGame(opts)
  opts = opts or {}
  mock.reset()
  local g = engine.new()
  g:loadItems("examples/cave/data/items.lua")
  g:loadCreatures("examples/cave/data/creatures.lua")
  g:loadRooms("examples/cave/data/rooms.lua")
  g:registerCharacter({ id = "rin", name = "Rin", description = "A wiry traveler." })
  if not opts.solo then
    g:registerCharacter({ id = "gar", name = "Gar", description = "A heavy companion." })
  end
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

function T.first_registered_is_active()
  local g = newGame()
  h.assertEq(g:active().id, "rin")
end

function T.look_describes_room()
  local g = newGame()
  mock.clear()
  g:dispatch("look")
  h.assertContains(mock.output(), "Edge of the Forest")
  h.assertContains(mock.output(), "brass lantern")
  h.assertContains(mock.output(), "north")
end

function T.take_goes_to_active_actor()
  local g = newGame()
  g:dispatch("take lantern")
  h.assertTrue(engine.character.hasItem(g:active(), "lantern"))
  h.assertEq(g:active().id, "rin")
end

function T.take_uses_alias()
  local g = newGame()
  g:dispatch("take lamp")
  h.assertTrue(engine.character.hasItem(g:active(), "lantern"))
end

function T.take_rejects_untakeable()
  local g = newGame()
  g.state.party.location = "cave_entrance"
  mock.clear()
  g:dispatch("take boulder")
  h.assertContains(mock.output(), "can't take")
end

function T.party_movement_moves_everyone()
  local g = newGame()
  g:dispatch("north")
  h.assertEq(g.state.party.location, "cave_entrance")
  g:dispatch("s")
  h.assertEq(g.state.party.location, "forest")
end

function T.movement_blocked_when_no_exit()
  local g = newGame()
  mock.clear()
  g:dispatch("west")
  h.assertContains(mock.output(), "can't go that way")
end

function T.drop_returns_item_to_room_at_party_location()
  local g = newGame()
  g:dispatch("take lantern")
  g:dispatch("north")
  g:dispatch("drop lantern")
  local items = engine.state.itemsInRoom(g.state, "cave_entrance")
  local found = false
  for _, id in ipairs(items) do if id == "lantern" then found = true end end
  h.assertTrue(found, "lantern should be in cave_entrance after drop")
  h.assertEq(engine.character.hasItem(g:active(), "lantern"), false)
end

function T.examine_inventory_item_of_active_actor()
  local g = newGame()
  g:dispatch("take lantern")
  mock.clear()
  g:dispatch("examine lamp")
  h.assertContains(mock.output(), "warm glow")
end

function T.examine_party_member_describes_them()
  local g = newGame()
  mock.clear()
  g:dispatch("examine gar")
  h.assertContains(mock.output(), "heavy companion")
end

function T.unknown_word()
  local g = newGame()
  mock.clear()
  g:dispatch("flarp")
  h.assertContains(mock.output(), "flarp")
end

function T.custom_verb_runs_for_active_actor()
  local g = newGame()
  local actorId
  g:registerVerb("ping", function(eng) actorId = eng:active().id end)
  g:dispatch("ping")
  h.assertEq(actorId, "rin")
  g:dispatch("switch gar")
  g:dispatch("ping")
  h.assertEq(actorId, "gar")
end

function T.switch_changes_active()
  local g = newGame()
  g:dispatch("switch gar")
  h.assertEq(g:active().id, "gar")
end

function T.switch_unknown_member()
  local g = newGame()
  mock.clear()
  g:dispatch("switch ghost")
  h.assertContains(mock.output(), "No party member")
  h.assertEq(g:active().id, "rin")
end

function T.address_prefix_runs_as_named_actor()
  local g = newGame()
  g:dispatch("gar: take lantern")
  h.assertTrue(engine.character.hasItem(g:partyMember("gar"), "lantern"))
  h.assertEq(engine.character.hasItem(g:partyMember("rin"), "lantern"), false)
end

function T.address_prefix_reverts_active_after()
  local g = newGame()
  g:dispatch("gar: take lantern")
  h.assertEq(g:active().id, "rin", "active should revert to rin after one-shot")
end

function T.address_prefix_does_not_revert_explicit_switch()
  local g = newGame()
  g:dispatch("switch gar")
  g:dispatch("rin: look")
  h.assertEq(g:active().id, "gar", "explicit switch should still hold after one-shot")
end

function T.address_prefix_observes_temp_actor_during_verb()
  local g = newGame()
  local seen
  g:registerVerb("ping", function(eng) seen = eng:active().id end)
  g:dispatch("gar: ping")
  h.assertEq(seen, "gar", "verb should see gar as active during the one-shot")
  h.assertEq(g:active().id, "rin", "but active reverts after")
end

function T.address_prefix_with_unknown_actor()
  local g = newGame()
  mock.clear()
  g:dispatch("nobody: take lantern")
  h.assertContains(mock.output(), "No one named")
  h.assertEq(g:active().id, "rin")
end

function T.address_prefix_alone_is_noop()
  local g = newGame()
  g:dispatch("gar:")
  h.assertEq(g:active().id, "rin", "empty action after prefix should not change active")
end

function T.party_listing()
  local g = newGame()
  mock.clear()
  g:dispatch("party")
  h.assertContains(mock.output(), "Rin")
  h.assertContains(mock.output(), "Gar")
  h.assertContains(mock.output(), "active")
end

function T.inventory_of_named_member()
  local g = newGame()
  g:dispatch("take lantern")
  mock.clear()
  g:dispatch("inventory rin")
  h.assertContains(mock.output(), "brass lantern")
  mock.clear()
  g:dispatch("inventory gar")
  h.assertContains(mock.output(), "Gar carries nothing")
end

function T.snapshot_round_trip_with_party()
  local g = newGame()
  g:dispatch("take lantern")
  g:dispatch("switch gar")
  g:dispatch("north")
  local snap = g:snapshot()
  g:dispatch("drop lantern")
  g:dispatch("south")
  g:dispatch("switch rin")
  g:restore(snap)
  h.assertEq(g.state.party.location, "cave_entrance")
  h.assertEq(g:active().id, "gar")
  h.assertTrue(engine.character.hasItem(g:partyMember("rin"), "lantern"))
end

function T.run_quits_on_quit_verb()
  local g = newGame()
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(g._running, false)
end

function T.run_requires_character()
  local g = engine.new()
  g:loadRooms("examples/cave/data/rooms.lua")
  g:setStart("forest")
  h.assertThrows(function() g:run() end, "character")
end

function T.run_requires_start()
  local g = engine.new()
  g:loadRooms("examples/cave/data/rooms.lua")
  g:registerCharacter({ id = "rin" })
  h.assertThrows(function() g:run() end, "setStart")
end

return T
