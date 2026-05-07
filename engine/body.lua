local M = {}

M.SLOTS = {
  head  = { max = 1 },
  torso = { max = 1 },
  arms  = { max = 4 },
  legs  = { max = 2 },
  wings = { max = 2 },
  tail  = { max = 1 },
}

local CONDITIONS = { healthy = true, injured = true, missing = true, restrained = true }

function M.new()
  local b = { slots = {} }
  for name in pairs(M.SLOTS) do b.slots[name] = {} end
  return b
end

function M.attach(body, partDef, eng, char)
  local slotName = partDef.slot
  local spec = M.SLOTS[slotName]
  assert(spec, "unknown slot '" .. tostring(slotName) .. "'")
  local current = body.slots[slotName]
  assert(#current < spec.max,
    "slot '" .. slotName .. "' is full (max " .. spec.max .. ")")
  local instance = { defId = partDef.id, condition = "healthy", equipment = {} }
  table.insert(current, instance)
  if partDef.onAttach then partDef.onAttach(eng, char, instance) end
  return instance
end

function M.detach(body, slotName, index, partDef, eng, char)
  local instances = body.slots[slotName]
  if not instances or not instances[index] then return false end
  local instance = instances[index]
  if partDef and partDef.onDetach then partDef.onDetach(eng, char, instance) end
  table.remove(instances, index)
  return true
end

function M.setCondition(body, slotName, index, newCond, partDef, eng, char)
  assert(CONDITIONS[newCond], "unknown condition '" .. tostring(newCond) ..
    "'; valid: healthy, injured, missing, restrained")
  local instances = body.slots[slotName]
  local instance = instances and instances[index]
  if not instance then return false end
  local old = instance.condition
  if old == newCond then return true end
  instance.condition = newCond
  if partDef and partDef.onConditionChange then
    partDef.onConditionChange(eng, char, instance, old, newCond)
  end
  return true
end

function M.iterInstances(body, fn)
  for slotName, instances in pairs(body.slots) do
    for i, instance in ipairs(instances) do
      fn(slotName, i, instance)
    end
  end
end

function M.tickParts(body, partReg, eng, char, turn)
  M.iterInstances(body, function(_, _, instance)
    local def = partReg[instance.defId]
    if def and def.onTick then def.onTick(eng, char, instance, turn) end
  end)
end

function M.turnStartParts(body, partReg, eng, char)
  M.iterInstances(body, function(_, _, instance)
    local def = partReg[instance.defId]
    if def and def.onTurnStart then def.onTurnStart(eng, char, instance) end
  end)
end

function M.turnEndParts(body, partReg, eng, char)
  M.iterInstances(body, function(_, _, instance)
    local def = partReg[instance.defId]
    if def and def.onTurnEnd then def.onTurnEnd(eng, char, instance) end
  end)
end

function M.findFreeEquipSlot(body, partReg, equipSlotType)
  for slotName, instances in pairs(body.slots) do
    for i, instance in ipairs(instances) do
      if instance.condition == "healthy" then
        local def = partReg[instance.defId]
        if def and def.equipSlots then
          for _, slotType in ipairs(def.equipSlots) do
            if slotType == equipSlotType and not instance.equipment[slotType] then
              return slotName, i, slotType, instance
            end
          end
        end
      end
    end
  end
  return nil
end

function M.findEquipped(body, itemId)
  for slotName, instances in pairs(body.slots) do
    for i, instance in ipairs(instances) do
      for slotType, equippedId in pairs(instance.equipment) do
        if equippedId == itemId then
          return slotName, i, slotType, instance
        end
      end
    end
  end
  return nil
end

M.HUMANOID_PARTS = {
  { id = "__human_head",      slot = "head",  name = "head" },
  { id = "__human_torso",     slot = "torso", name = "torso" },
  { id = "__human_right_arm", slot = "arms",  name = "right arm", equipSlots = { "hold", "wear" } },
  { id = "__human_left_arm",  slot = "arms",  name = "left arm",  equipSlots = { "hold", "wear" } },
  { id = "__human_right_leg", slot = "legs",  name = "right leg", equipSlots = { "wear" } },
  { id = "__human_left_leg",  slot = "legs",  name = "left leg",  equipSlots = { "wear" } },
}

return M
