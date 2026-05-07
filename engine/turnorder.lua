local M = {}

function M.isPlayerActor(actor, partyChars)
  if actor.isPlayer ~= nil then return actor.isPlayer end
  if actor.act then return false end
  return partyChars[actor.id] ~= nil
end

local function partitioned(actorList, partyChars)
  local players, npcs = {}, {}
  for _, a in ipairs(actorList) do
    if M.isPlayerActor(a, partyChars) then players[#players + 1] = a.id
    else npcs[#npcs + 1] = a.id end
  end
  return players, npcs
end

function M.playersFirst(actorList, partyChars)
  local players, npcs = partitioned(actorList, partyChars)
  for _, id in ipairs(npcs) do players[#players + 1] = id end
  return players
end

function M.npcsFirst(actorList, partyChars)
  local players, npcs = partitioned(actorList, partyChars)
  for _, id in ipairs(players) do npcs[#npcs + 1] = id end
  return npcs
end

function M.random(actorList, _partyChars)
  local ids = {}
  for _, a in ipairs(actorList) do ids[#ids + 1] = a.id end
  for i = #ids, 2, -1 do
    local j = math.random(i)
    ids[i], ids[j] = ids[j], ids[i]
  end
  return ids
end

return M
