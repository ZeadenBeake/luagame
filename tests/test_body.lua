local h = require "tests.helpers"
local body = require "engine.body"

local function makePartDef(overrides)
  local def = { id = "test_arm", slot = "arms", name = "test arm" }
  for k, v in pairs(overrides or {}) do def[k] = v end
  return def
end

local T = {}

function T.new_has_all_slots()
  local b = body.new()
  for slotName in pairs(body.SLOTS) do
    h.assertTrue(b.slots[slotName] ~= nil, "missing slot: " .. slotName)
  end
end

function T.attach_returns_instance()
  local b = body.new()
  local def = makePartDef()
  local inst = body.attach(b, def, nil, nil)
  h.assertEq(inst.defId, "test_arm")
  h.assertEq(inst.condition, "healthy")
  h.assertEq(#b.slots.arms, 1)
end

function T.attach_respects_slot_max()
  local b = body.new()
  local def = makePartDef({ slot = "head" })
  body.attach(b, def, nil, nil)
  h.assertThrows(function()
    body.attach(b, makePartDef({ id = "head2", slot = "head" }), nil, nil)
  end, "full")
end

function T.attach_rejects_unknown_slot()
  local b = body.new()
  h.assertThrows(function()
    body.attach(b, makePartDef({ slot = "tentacle" }), nil, nil)
  end, "unknown slot")
end

function T.attach_fires_onAttach()
  local b = body.new()
  local fired = false
  local def = makePartDef({ onAttach = function() fired = true end })
  body.attach(b, def, nil, nil)
  h.assertTrue(fired)
end

function T.detach_removes_instance_fires_onDetach()
  local b = body.new()
  local detached = false
  local def = makePartDef({ onDetach = function() detached = true end })
  body.attach(b, def, nil, nil)
  h.assertTrue(body.detach(b, "arms", 1, def, nil, nil))
  h.assertEq(#b.slots.arms, 0)
  h.assertTrue(detached)
end

function T.detach_returns_false_for_missing_index()
  local b = body.new()
  h.assertEq(body.detach(b, "arms", 1, nil, nil, nil), false)
end

function T.set_condition_fires_hook()
  local b = body.new()
  local old, new
  local def = makePartDef({
    onConditionChange = function(_, _, _, o, n) old = o; new = n end
  })
  body.attach(b, def, nil, nil)
  body.setCondition(b, "arms", 1, "injured", def, nil, nil)
  h.assertEq(old, "healthy")
  h.assertEq(new, "injured")
end

function T.set_condition_rejects_invalid()
  local b = body.new()
  local def = makePartDef()
  body.attach(b, def, nil, nil)
  h.assertThrows(function()
    body.setCondition(b, "arms", 1, "shattered", def, nil, nil)
  end, "unknown condition")
end

function T.set_condition_noop_when_same()
  local b = body.new()
  local calls = 0
  local def = makePartDef({ onConditionChange = function() calls = calls + 1 end })
  body.attach(b, def, nil, nil)
  body.setCondition(b, "arms", 1, "healthy", def, nil, nil)
  h.assertEq(calls, 0)
end

function T.tick_fires_ontick_for_each_part()
  local b = body.new()
  local ticked = 0
  local def = makePartDef({ onTick = function() ticked = ticked + 1 end })
  local partReg = { test_arm = def }
  body.attach(b, def, nil, nil)
  body.attach(b, makePartDef({ id = "test_arm2",
    onTick = function() ticked = ticked + 1 end }), nil, nil)
  body.tickParts(b, partReg, nil, nil, 1)
  h.assertEq(ticked, 1) -- only first arm has entry in partReg
end

function T.find_free_equip_slot()
  local b = body.new()
  local def = makePartDef({ equipSlots = { "hold" } })
  local partReg = { test_arm = def }
  body.attach(b, def, nil, nil)
  local _, _, sType, inst = body.findFreeEquipSlot(b, partReg, "hold")
  h.assertEq(sType, "hold")
  h.assertTrue(inst ~= nil)
end

function T.find_free_equip_slot_blocked_when_full()
  local b = body.new()
  local def = makePartDef({ equipSlots = { "hold" } })
  local partReg = { test_arm = def }
  local inst = body.attach(b, def, nil, nil)
  inst.equipment["hold"] = "lantern"
  local _, _, _, found = body.findFreeEquipSlot(b, partReg, "hold")
  h.assertEq(found, nil)
end

function T.find_equipped_locates_item()
  local b = body.new()
  local def = makePartDef({ equipSlots = { "hold" } })
  local inst = body.attach(b, def, nil, nil)
  inst.equipment["hold"] = "lantern"
  local _, _, sType, found = body.findEquipped(b, "lantern")
  h.assertEq(sType, "hold")
  h.assertTrue(found == inst)
end

function T.humanoid_parts_cover_expected_slots()
  local slots = {}
  for _, p in ipairs(body.HUMANOID_PARTS) do
    slots[p.slot] = (slots[p.slot] or 0) + 1
  end
  h.assertEq(slots.head, 1)
  h.assertEq(slots.torso, 1)
  h.assertEq(slots.arms, 2)
  h.assertEq(slots.legs, 2)
end

return T
