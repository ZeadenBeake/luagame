local h = require "tests.helpers"
local mock = require "tests.cc_mock"
local engine = require "engine"

-- Minimal game: one room, characters loaded from cave example
local function newGame()
  mock.reset()
  local g = engine.new()
  g:loadItems("examples/cave/data/items.lua")
  g:loadCreatures("examples/cave/data/creatures.lua")
  g:loadRooms("examples/cave/data/rooms.lua")
  g:registerCharacter({ id = "rin", name = "Rin", body = "humanoid" })
  g:registerCharacter({ id = "gar", name = "Gar", body = "humanoid" })
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

local function startSimple(g, actors, opts)
  local full = { actors = actors }
  for k, v in pairs(opts or {}) do full[k] = v end
  g:startEncounter(full)
end

local T = {}

function T.inEncounter_false_before_start()
  local g = newGame()
  h.assertEq(g:inEncounter(), false)
end

function T.inEncounter_true_after_start()
  local g = newGame()
  startSimple(g, { { id = "rin" } })
  h.assertEq(g:inEncounter(), true)
end

function T.endEncounter_clears_state()
  local g = newGame()
  startSimple(g, { { id = "rin" } })
  g:endEncounter("done")
  h.assertEq(g:inEncounter(), false)
  h.assertEq(g._encounter, nil)
end

function T.startEncounter_rejects_double_start()
  local g = newGame()
  startSimple(g, { { id = "rin" } })
  h.assertThrows(function() startSimple(g, { { id = "rin" } }) end, "already in an encounter")
end

function T.startEncounter_needs_actors()
  local g = newGame()
  h.assertThrows(function() g:startEncounter({}) end, "needs at least one actor")
end

function T.onEnd_callback_fires_with_reason()
  local g = newGame()
  local gotReason
  startSimple(g, { { id = "rin" } }, { onEnd = function(_, r) gotReason = r end })
  g:endEncounter("victory")
  h.assertEq(gotReason, "victory")
end

function T.ai_actor_act_called_on_their_turn()
  local g = newGame()
  local acted = false
  startSimple(g, {
    { id = "goblin", name = "Goblin",
      act = function(eng, _) acted = true; eng:endEncounter("done") end },
  })
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertTrue(acted)
end

function T.player_turn_ends_when_ap_depleted()
  local g = newGame()
  local rounds = 0
  startSimple(g, {
    { id = "rin" },
    { id = "goblin", name = "Goblin",
      act = function(eng, _)
        rounds = rounds + 1
        if rounds >= 2 then eng:endEncounter("done") end
      end },
  })
  -- Rin has 1 AP; taking lantern costs 1 AP via tick() → turn auto-ends
  mock.queueInput("take lantern")
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertTrue(rounds >= 1, "goblin should have acted at least once")
  h.assertTrue(engine.character.hasItem(g:partyMember("rin"), "lantern"))
end

function T.endturn_verb_advances_manually()
  local g = newGame()
  local goblinTurns = 0
  startSimple(g, {
    { id = "rin" },
    { id = "goblin", name = "Goblin",
      act = function(eng, _)
        goblinTurns = goblinTurns + 1
        if goblinTurns >= 2 then eng:endEncounter("done") end
      end },
  })
  -- Rin has 1 AP but we end turn before using it
  mock.queueInput("endturn")
  mock.queueInput("endturn")
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(goblinTurns, 2)
end

function T.multi_ap_turn()
  local g = newGame()
  local rinActions = 0
  local goblinTurns = 0
  g:registerVerb("ping", function(eng)
    rinActions = rinActions + 1
    eng:tick()
  end)
  startSimple(g, {
    { id = "rin", maxAp = 2 },
    { id = "goblin", name = "Goblin",
      act = function(eng, _)
        goblinTurns = goblinTurns + 1
        eng:endEncounter("done")
      end },
  })
  -- Rin has 2 AP; two pings use both
  mock.queueInput("ping")
  mock.queueInput("ping")
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(rinActions, 2)
  h.assertEq(goblinTurns, 1)
end

function T.free_verb_does_not_spend_ap()
  local g = newGame()
  local goblinTurns = 0
  startSimple(g, {
    { id = "rin" },
    { id = "goblin", name = "Goblin",
      act = function(eng, _)
        goblinTurns = goblinTurns + 1
        eng:endEncounter("done")
      end },
  })
  -- look is free; endturn explicitly passes
  mock.queueInput("look")
  mock.queueInput("look")
  mock.queueInput("endturn")
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(goblinTurns, 1)
end

function T.turn_order_list()
  local g = newGame()
  local log = {}
  startSimple(g, {
    { id = "rin" },
    { id = "gar" },
  }, {
    turnOrder = { "gar", "rin" },
    onTurnStart = function(_, id) log[#log + 1] = id end,
    onEnd = function() end,
  })
  mock.queueInput("endturn")  -- gar's turn
  mock.queueInput("endturn")  -- rin's turn
  mock.queueInput("quit")     -- exit before round 2 completes
  g:run({ skipSeed = true })
  h.assertEq(log[1], "gar")
  h.assertEq(log[2], "rin")
end

function T.turn_order_playersFirst()
  local g = newGame()
  local order = engine.turnorder.playersFirst(
    { { id = "goblin", act = function() end }, { id = "rin" }, { id = "gar" } },
    g.state.party.characters
  )
  h.assertEq(order[1], "rin")
  h.assertEq(order[2], "gar")
  h.assertEq(order[3], "goblin")
end

function T.turn_order_npcsFirst()
  local g = newGame()
  local order = engine.turnorder.npcsFirst(
    { { id = "goblin", act = function() end }, { id = "rin" }, { id = "gar" } },
    g.state.party.characters
  )
  h.assertEq(order[1], "goblin")
  h.assertEq(order[2], "rin")
  h.assertEq(order[3], "gar")
end

function T.turn_order_random_includes_all()
  local g = newGame()
  local actors = { { id = "a", act = function() end }, { id = "rin" }, { id = "gar" } }
  local order = engine.turnorder.random(actors, g.state.party.characters)
  table.sort(order)
  h.assertEq(#order, 3)
  h.assertEq(order[1], "a")
  h.assertEq(order[2], "gar")
  h.assertEq(order[3], "rin")
end

function T.next_actor_fn_controls_order()
  local g = newGame()
  local seq = { "rin", "gar", "rin" }
  local step = 0
  local log = {}
  startSimple(g, { { id = "rin" }, { id = "gar" } }, {
    nextActor = function(eng, _)
      step = step + 1
      if step > #seq then eng:endEncounter("done"); return nil end
      return seq[step]
    end,
    onTurnStart = function(_, id) log[#log + 1] = id end,
  })
  -- two player turns, then encounter ends from nextActor returning nil
  mock.queueInput("endturn")  -- rin
  mock.queueInput("endturn")  -- gar
  mock.queueInput("endturn")  -- rin again
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(log[1], "rin")
  h.assertEq(log[2], "gar")
  h.assertEq(log[3], "rin")
end

function T.body_turnStart_turnEnd_hooks_fire()
  local g = newGame()
  g:registerPart({
    id = "hook_arm", slot = "arms",
    onTurnStart = function(_, char, _) char.flags.turnStarted = true end,
    onTurnEnd   = function(_, char, _) char.flags.turnEnded  = true end,
  })
  local rin = g:partyMember("rin")
  g:attachPart(rin, "hook_arm")
  startSimple(g, {
    { id = "rin" },
    { id = "goblin", name = "Goblin",
      act = function(eng, _) eng:endEncounter("done") end },
  })
  mock.queueInput("endturn")
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertTrue(rin.flags.turnStarted, "onTurnStart should have fired")
  h.assertTrue(rin.flags.turnEnded,   "onTurnEnd should have fired")
end

function T.onTurnStart_onTurnEnd_callbacks_fire()
  local g = newGame()
  local starts, ends = {}, {}
  startSimple(g, {
    { id = "rin" },
    { id = "goblin", name = "Goblin",
      act = function(eng, _) eng:endEncounter("done") end },
  }, {
    onTurnStart = function(_, id) starts[#starts + 1] = id end,
    onTurnEnd   = function(_, id) ends[#ends + 1]   = id end,
  })
  mock.queueInput("endturn")
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(starts[1], "rin")
  h.assertEq(ends[1],   "rin")
  h.assertEq(starts[2], "goblin")
end

function T.endturn_outside_encounter_prints_message()
  local g = newGame()
  mock.clear()
  g:dispatch("endturn")
  h.assertContains(mock.output(), "aren't in an encounter")
end

function T.encounter_state_round_trips_snapshot()
  local g = newGame()
  startSimple(g, { { id = "rin" }, { id = "gar" } })
  g.state.encounter.currentIndex = 2
  local snap = g:snapshot()
  g.state.encounter.currentIndex = 1
  g:restore(snap)
  h.assertEq(g.state.encounter.currentIndex, 2)
  h.assertEq(g.state.encounter.active, true)
end

function T.exploration_resumes_after_encounter()
  local g = newGame()
  startSimple(g, {
    { id = "goblin", name = "Goblin",
      act = function(eng, _) eng:endEncounter("done") end },
  })
  mock.queueInput("quit")
  g:run({ skipSeed = true })
  h.assertEq(g:inEncounter(), false)
  h.assertEq(g._running, false)
end

return T
