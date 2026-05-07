local h = require "tests.helpers"
local mock = require "tests.cc_mock"
local engine = require "engine"

local function newGame()
  mock.reset()
  local g = engine.new()
  g:loadItems("examples/cave/data/items.lua")
  g:loadCreatures("examples/cave/data/creatures.lua")
  g:loadRooms("examples/cave/data/rooms.lua")
  g:registerCharacter({ id = "rin", name = "Rin" })
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

function T.turn_starts_at_zero()
  local g = newGame()
  h.assertEq(g.state.world.turn, 0)
end

function T.tick_increments_turn()
  local g = newGame()
  g:tick()
  h.assertEq(g.state.world.turn, 1)
  g:tick()
  h.assertEq(g.state.world.turn, 2)
end

function T.action_verb_consumes_turn()
  local g = newGame()
  g:dispatch("take lantern")
  h.assertEq(g.state.world.turn, 1)
end

function T.informational_verb_does_not_consume_turn()
  local g = newGame()
  g:dispatch("look")
  g:dispatch("inventory")
  g:dispatch("examine lantern")
  g:dispatch("party")
  g:dispatch("switch rin")
  h.assertEq(g.state.world.turn, 0)
end

function T.movement_consumes_turn()
  local g = newGame()
  g:dispatch("north")
  h.assertEq(g.state.world.turn, 1)
  g:dispatch("south")
  h.assertEq(g.state.world.turn, 2)
end

function T.failed_verb_does_not_consume_turn()
  local g = newGame()
  g:dispatch("take boulder")     -- boulder exists but is not takeable
  g:dispatch("take ghost")       -- nothing to take
  g:dispatch("flarp")            -- unknown word
  g:dispatch("go east")          -- no exit
  h.assertEq(g.state.world.turn, 0)
end

function T.ontick_fires_each_tick()
  local g = newGame()
  local calls = {}
  g:onTick(function(eng, turn) calls[#calls + 1] = turn end)
  g:dispatch("take lantern")
  g:dispatch("north")
  h.assertEq(#calls, 2)
  h.assertEq(calls[1], 1)
  h.assertEq(calls[2], 2)
end

function T.scheduleat_fires_once_at_right_turn()
  local g = newGame()
  local fired = 0
  g:scheduleAt(3, function() fired = fired + 1 end)
  g:tick(); g:tick()
  h.assertEq(fired, 0)
  g:tick()
  h.assertEq(fired, 1)
  g:tick()
  h.assertEq(fired, 1, "should not fire again")
end

function T.schedulein_fires_relative_to_current_turn()
  local g = newGame()
  g:tick(); g:tick()
  local fired = false
  g:scheduleIn(3, function() fired = true end)
  g:tick(); g:tick()
  h.assertEq(fired, false)
  g:tick()
  h.assertEq(fired, true)
end

function T.multiple_events_at_same_turn_all_fire()
  local g = newGame()
  local log = {}
  g:scheduleAt(1, function() log[#log + 1] = "a" end)
  g:scheduleAt(1, function() log[#log + 1] = "b" end)
  g:tick()
  h.assertEq(#log, 2)
end

function T.event_can_schedule_followup_event()
  local g = newGame()
  local log = {}
  g:scheduleAt(1, function(eng)
    log[#log + 1] = "first"
    eng:scheduleIn(1, function() log[#log + 1] = "second" end)
  end)
  g:tick()
  h.assertEq(log[1], "first")
  h.assertEq(log[2], nil)
  g:tick()
  h.assertEq(log[2], "second")
end

function T.ontick_sees_new_turn_value()
  local g = newGame()
  local seen = {}
  g:onTick(function(_, turn) seen[#seen + 1] = turn end)
  g:tick(); g:tick(); g:tick()
  h.assertEq(seen[1], 1)
  h.assertEq(seen[2], 2)
  h.assertEq(seen[3], 3)
end

function T.snapshot_preserves_turn()
  local g = newGame()
  g:tick(); g:tick()
  local snap = g:snapshot()
  g:tick()
  g:restore(snap)
  h.assertEq(g.state.world.turn, 2)
end

function T.schedulein_validates_positive_delta()
  local g = newGame()
  h.assertThrows(function() g:scheduleIn(0, function() end) end, "positive")
  h.assertThrows(function() g:scheduleIn(-1, function() end) end, "positive")
end

return T
