local M = {}

local aggregators = {
  any = function(values)
    for _, v in ipairs(values) do if v then return true end end
    return false
  end,
  all = function(values)
    if #values == 0 then return false end
    for _, v in ipairs(values) do if not v then return false end end
    return true
  end,
  sum = function(values)
    local total = 0
    for _, v in ipairs(values) do total = total + (tonumber(v) or 0) end
    return total
  end,
  max = function(values)
    local best = nil
    for _, v in ipairs(values) do
      local n = tonumber(v)
      if n and (not best or n > best) then best = n end
    end
    return best or 0
  end,
}

function M.new() return {} end

function M.register(capReg, name, aggregation)
  assert(type(name) == "string" and name ~= "", "capability name must be a non-empty string")
  assert(aggregators[aggregation],
    "unknown aggregation '" .. tostring(aggregation) .. "'; valid: any, all, sum, max")
  capReg[name] = aggregation
end

local function collectFromDef(def, capName, values)
  if def and def.provides and def.provides[capName] ~= nil then
    values[#values + 1] = def.provides[capName]
  end
end

local function declaresCapability(def, capName)
  return def and def.provides and def.provides[capName] ~= nil
end

function M.query(capReg, char, partReg, itemReg, capName)
  local aggregation = capReg[capName]
  if not aggregation then return nil end

  if aggregation == "all" then
    -- Every part (and equipped item) that declares this capability must be
    -- healthy and have a truthy value; absence of any providers → false.
    local anyProvider = false
    for _, instances in pairs(char.body.slots) do
      for _, instance in ipairs(instances) do
        local def = partReg[instance.defId]
        if declaresCapability(def, capName) then
          anyProvider = true
          if instance.condition ~= "healthy" or not def.provides[capName] then
            return false
          end
        end
        for _, itemId in pairs(instance.equipment) do
          local idef = itemReg[itemId]
          if declaresCapability(idef, capName) then
            anyProvider = true
            if instance.condition ~= "healthy" or not idef.provides[capName] then
              return false
            end
          end
        end
      end
    end
    return anyProvider
  end

  -- any / sum / max: only healthy parts contribute
  local values = {}
  for _, instances in pairs(char.body.slots) do
    for _, instance in ipairs(instances) do
      if instance.condition == "healthy" then
        collectFromDef(partReg[instance.defId], capName, values)
        for _, itemId in pairs(instance.equipment) do
          collectFromDef(itemReg[itemId], capName, values)
        end
      end
    end
  end
  return aggregators[aggregation](values)
end

return M
