local M = {}

function M.tokenize(input)
  local tokens = {}
  for w in (input or ""):gmatch("%S+") do
    table.insert(tokens, w:lower())
  end
  return tokens
end

function M.parse(input, verbs)
  local tokens = M.tokenize(input)
  if #tokens == 0 then return nil end
  local first = tokens[1]
  local aliases = verbs._aliases or {}
  local verb = (verbs[first] and first) or aliases[first]
  if not verb then return nil, first end
  local rest = {}
  for i = 2, #tokens do rest[i - 1] = tokens[i] end
  return verb, rest
end

function M.resolveTarget(words, candidates, registry)
  if not words or #words == 0 then return nil end
  local phrase = table.concat(words, " ")
  for _, id in ipairs(candidates) do
    local def = registry[id]
    if def then
      if id == phrase or (def.name and def.name:lower() == phrase) then
        return id
      end
      if def.aliases then
        for _, alias in ipairs(def.aliases) do
          if alias:lower() == phrase then return id end
        end
      end
    end
  end
  for _, id in ipairs(candidates) do
    local def = registry[id]
    if def and def.name and def.name:lower():find(phrase, 1, true) then
      return id
    end
  end
  return nil
end

return M
