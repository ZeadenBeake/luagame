local h = require "tests.helpers"
local mock = require "tests.cc_mock"
local engine = require "engine"

local function newGame()
  mock.reset()
  local g = engine.new()
  g:registerCapability("flight", "all")
  g:registerCapability("grip",   "sum")
  g:registerCapability("keen",   "any")
  g:registerCapability("power",  "max")
  return g
end

local function charWithParts(g, parts)
  g:registerCharacter({ id = "tester", name = "Tester" })
  local char = g:partyMember("tester")
  for _, def in ipairs(parts) do
    g:registerPart(def)
    g:attachPart(char, def.id)
  end
  return char
end

local T = {}

function T.unregistered_capability_returns_nil()
  local g = newGame()
  g:registerCharacter({ id = "t" })
  local char = g:partyMember("t")
  h.assertEq(g:queryCapability(char, "unknown"), nil)
end

function T.any_true_if_any_healthy_part_provides()
  local g = newGame()
  local char = charWithParts(g, {
    { id = "sharp_nose", slot = "head", provides = { keen = true } },
  })
  h.assertEq(g:queryCapability(char, "keen"), true)
end

function T.any_false_if_no_healthy_part_provides()
  local g = newGame()
  local char = charWithParts(g, {
    { id = "sharp_nose", slot = "head", provides = { keen = true } },
  })
  g:setPartCondition(char, "head", 1, "injured")
  h.assertEq(g:queryCapability(char, "keen"), false)
end

function T.all_true_only_when_all_providers_healthy()
  local g = newGame()
  local char = charWithParts(g, {
    { id = "wing_l", slot = "wings", provides = { flight = true } },
    { id = "wing_r", slot = "wings", provides = { flight = true } },
  })
  h.assertEq(g:queryCapability(char, "flight"), true)
  g:setPartCondition(char, "wings", 1, "injured")
  h.assertEq(g:queryCapability(char, "flight"), false)
end

function T.all_false_when_no_providers()
  local g = newGame()
  g:registerCharacter({ id = "t" })
  local char = g:partyMember("t")
  h.assertEq(g:queryCapability(char, "flight"), false)
end

function T.sum_across_healthy_parts()
  local g = newGame()
  local char = charWithParts(g, {
    { id = "strong_r", slot = "arms", provides = { grip = 3 } },
    { id = "strong_l", slot = "arms", provides = { grip = 2 } },
  })
  h.assertEq(g:queryCapability(char, "grip"), 5)
  g:setPartCondition(char, "arms", 1, "missing")
  h.assertEq(g:queryCapability(char, "grip"), 2)
end

function T.max_returns_highest_healthy_value()
  local g = newGame()
  local char = charWithParts(g, {
    { id = "leg_r", slot = "legs", provides = { power = 4 } },
    { id = "leg_l", slot = "legs", provides = { power = 7 } },
  })
  h.assertEq(g:queryCapability(char, "power"), 7)
end

function T.equipped_item_contributes_to_capability()
  local g = newGame()
  g:registerItem({
    id = "power_glove", name = "power glove",
    fitsIn = { "hold" },
    provides = { grip = 5 },
  })
  local char = charWithParts(g, {
    { id = "plain_arm", slot = "arms", provides = { grip = 1 }, equipSlots = { "hold" } },
  })
  h.assertEq(g:queryCapability(char, "grip"), 1)
  g:loadItems("examples/cave/data/items.lua")  -- ensure registry has items loaded
  -- manually equip by inserting into equipment
  char.body.slots.arms[1].equipment["hold"] = "power_glove"
  h.assertEq(g:queryCapability(char, "grip"), 6)
end

function T.charHas_true_for_nonzero_sum()
  local g = newGame()
  local char = charWithParts(g, {
    { id = "gripping_arm", slot = "arms", provides = { grip = 1 } },
  })
  h.assertTrue(g:charHas(char, "grip"))
end

function T.charHas_false_for_zero_sum()
  local g = newGame()
  g:registerCharacter({ id = "t" })
  local char = g:partyMember("t")
  h.assertEq(g:charHas(char, "grip"), false)
end

function T.partyHas_true_if_any_member_qualifies()
  local g = newGame()
  g:registerCharacter({ id = "rin" })
  g:registerCharacter({ id = "gar" })
  local rin = g:partyMember("rin")
  g:registerPart({ id = "rin_wing_l", slot = "wings", provides = { flight = true } })
  g:registerPart({ id = "rin_wing_r", slot = "wings", provides = { flight = true } })
  g:attachPart(rin, "rin_wing_l")
  g:attachPart(rin, "rin_wing_r")
  h.assertTrue(g:partyHas("flight"))
end

function T.partyHas_false_when_no_one_qualifies()
  local g = newGame()
  g:registerCharacter({ id = "rin" })
  h.assertEq(g:partyHas("flight"), false)
end

function T.register_capability_rejects_bad_aggregation()
  local g = engine.new()
  h.assertThrows(function()
    g:registerCapability("foo", "average")
  end, "aggregation")
end

function T.setup_humanoid_body_attaches_expected_slots()
  local g = engine.new()
  g:registerCharacter({ id = "rin", body = "humanoid" })
  local char = g:partyMember("rin")
  h.assertEq(#char.body.slots.arms, 2)
  h.assertEq(#char.body.slots.legs, 2)
  h.assertEq(#char.body.slots.head, 1)
  h.assertEq(#char.body.slots.wings, 0)
end

function T.custom_body_fn_runs_at_registration()
  local g = engine.new()
  g:registerPart({ id = "unique_tail", slot = "tail", name = "a tail" })
  local attached = false
  g:registerCharacter({
    id = "critter",
    body = function(char, eng)
      eng:attachPart(char, "unique_tail")
      attached = true
    end,
  })
  h.assertTrue(attached)
  h.assertEq(#g:partyMember("critter").body.slots.tail, 1)
end

return T
