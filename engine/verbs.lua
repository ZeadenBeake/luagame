local output = require "engine.output"
local state = require "engine.state"
local parser = require "engine.parser"
local party = require "engine.party"
local character = require "engine.character"
local body = require "engine.body"

local M = {}

local function itemName(eng, id)
  local def = eng.registry.items[id]
  return (def and def.name) or id
end

local function look(eng)
  local loc = eng.state.party.location
  local room = eng.registry.rooms[loc]
  if not room then output.print("You are nowhere."); return end
  output.print(room.name or room.id)
  output.blank()
  if room.description then output.print(room.description) end
  local items = state.itemsInRoom(eng.state, loc)
  if #items > 0 then
    output.blank()
    local names = {}
    for _, id in ipairs(items) do names[#names + 1] = itemName(eng, id) end
    output.print("You see: " .. table.concat(names, ", ") .. ".")
  end
  if room.creatures and #room.creatures > 0 then
    local names = {}
    for _, id in ipairs(room.creatures) do
      local def = eng.registry.creatures[id]
      names[#names + 1] = (def and def.name) or id
    end
    if #names > 0 then output.print("Also here: " .. table.concat(names, ", ") .. ".") end
  end
  if room.exits and next(room.exits) then
    local dirs = {}
    for d in pairs(room.exits) do dirs[#dirs + 1] = d end
    table.sort(dirs)
    output.print("Exits: " .. table.concat(dirs, ", ") .. ".")
  end
end

local function move(dir)
  return function(eng)
    local room = eng.registry.rooms[eng.state.party.location]
    if not room or not room.exits or not room.exits[dir] then
      output.print("You can't go that way.")
      return
    end
    local exitData = room.exits[dir]
    local targetId
    if type(exitData) == "string" then
      targetId = exitData
    else
      targetId = exitData.to
      if exitData.requires then
        for capName in pairs(exitData.requires) do
          if not eng:partyHas(capName) then
            output.print(exitData.blockedMessage or "You can't go that way.")
            return
          end
        end
      end
    end
    if not eng.registry.rooms[targetId] then
      output.print("The way is blocked.")
      return
    end
    eng.state.party.location = targetId
    look(eng)
    eng:tick()
  end
end

function M.builtins()
  local v = {}
  v._aliases = {
    n = "north", s = "south", e = "east", w = "west", u = "up", d = "down",
    i = "inventory", inv = "inventory",
    x = "examine",
    l = "look",
    q = "quit",
    p = "party",
  }

  v.look = function(eng) look(eng) end
  v.north = move("north"); v.south = move("south")
  v.east = move("east"); v.west = move("west")
  v.up = move("up"); v.down = move("down")

  v.go = function(eng, args)
    local dir = args and args[1]
    if not dir then output.print("Go where?"); return end
    local resolved = v._aliases[dir] or dir
    if v[resolved] then v[resolved](eng) else output.print("You can't go that way.") end
  end

  v.inventory = function(eng, args)
    local char
    if args and args[1] then
      local id = party.resolveByName(eng.state.party, table.concat(args, " "))
      if not id then output.print("No one by that name."); return end
      char = party.get(eng.state.party, id)
    else
      char = party.active(eng.state.party)
    end
    if not char then output.print("No one is here to check."); return end
    if #char.inventory == 0 then
      output.print(char.name .. " carries nothing.")
      return
    end
    output.print(char.name .. " is carrying:")
    for _, id in ipairs(char.inventory) do
      output.print("  " .. itemName(eng, id))
    end
  end

  v.take = function(eng, args)
    local char = party.active(eng.state.party)
    if not char then output.print("There is no one to act."); return end
    local roomItems = state.itemsInRoom(eng.state, eng.state.party.location)
    local id = parser.resolveTarget(args, roomItems, eng.registry.items)
    if not id then output.print("There is nothing like that here."); return end
    local def = eng.registry.items[id]
    if def and def.takeable == false then
      output.print(char.name .. " can't take that.")
      return
    end
    state.removeItemFromRoom(eng.state, eng.state.party.location, id)
    character.addItem(char, id)
    output.print(char.name .. " takes the " .. itemName(eng, id) .. ".")
    eng:tick()
  end

  v.drop = function(eng, args)
    local char = party.active(eng.state.party)
    if not char then output.print("There is no one to act."); return end
    local id = parser.resolveTarget(args, char.inventory, eng.registry.items)
    if not id then output.print(char.name .. " isn't carrying that."); return end
    character.removeItem(char, id)
    state.placeItem(eng.state, eng.state.party.location, id)
    output.print(char.name .. " drops the " .. itemName(eng, id) .. ".")
    eng:tick()
  end

  v.examine = function(eng, args)
    if args and args[1] then
      local memberId = party.resolveByName(eng.state.party, table.concat(args, " "))
      if memberId then
        local char = party.get(eng.state.party, memberId)
        output.print(char.description or char.name)
        return
      end
    end
    local pool = {}
    for _, id in ipairs(state.itemsInRoom(eng.state, eng.state.party.location)) do
      pool[#pool + 1] = id
    end
    local char = party.active(eng.state.party)
    if char then
      for _, id in ipairs(char.inventory) do pool[#pool + 1] = id end
    end
    local id = parser.resolveTarget(args, pool, eng.registry.items)
    if id then
      local def = eng.registry.items[id]
      output.print(def.description or def.name or id)
      return
    end
    local room = eng.registry.rooms[eng.state.party.location]
    local cIds = {}
    if room and room.creatures then
      for _, c in ipairs(room.creatures) do cIds[#cIds + 1] = c end
    end
    local cid = parser.resolveTarget(args, cIds, eng.registry.creatures)
    if cid then
      local def = eng.registry.creatures[cid]
      output.print(def.description or def.name or cid)
      return
    end
    output.print("You see nothing special.")
  end

  v.equip = function(eng, args)
    local char = party.active(eng.state.party)
    if not char then output.print("There is no one to act."); return end
    local id = parser.resolveTarget(args, char.inventory, eng.registry.items)
    if not id then output.print(char.name .. " isn't carrying that."); return end
    local def = eng.registry.items[id]
    if not def or not def.fitsIn or #def.fitsIn == 0 then
      output.print("That can't be equipped.")
      return
    end
    for _, slotType in ipairs(def.fitsIn) do
      local _, _, sType, instance = body.findFreeEquipSlot(char.body, eng.registry.parts, slotType)
      if instance and sType then
        character.removeItem(char, id)
        instance.equipment[sType] = id
        if def.onEquip then def.onEquip(eng, char, instance) end
        output.print(char.name .. " equips the " .. itemName(eng, id) .. ".")
        eng:tick()
        return
      end
    end
    output.print("There is nowhere suitable to equip that.")
  end

  v.unequip = function(eng, args)
    local char = party.active(eng.state.party)
    if not char then output.print("There is no one to act."); return end
    local equipped = {}
    body.iterInstances(char.body, function(_, _, instance)
      for _, itemId in pairs(instance.equipment) do
        equipped[#equipped + 1] = itemId
      end
    end)
    local id = parser.resolveTarget(args, equipped, eng.registry.items)
    if not id then output.print(char.name .. " doesn't have that equipped."); return end
    local _, _, sType, instance = body.findEquipped(char.body, id)
    if not instance or not sType then output.print(char.name .. " doesn't have that equipped."); return end
    local def = eng.registry.items[id]
    instance.equipment[sType] = nil
    character.addItem(char, id)
    if def and def.onUnequip then def.onUnequip(eng, char, instance) end
    output.print(char.name .. " unequips the " .. itemName(eng, id) .. ".")
    eng:tick()
  end

  v.switch = function(eng, args)
    if not args or not args[1] then output.print("Switch to whom?"); return end
    local id = party.resolveByName(eng.state.party, table.concat(args, " "))
    if not id then output.print("No party member by that name."); return end
    party.setActive(eng.state.party, id)
    output.print("Now controlling " .. party.get(eng.state.party, id).name .. ".")
  end

  v.party = function(eng)
    local list = party.list(eng.state.party)
    if #list == 0 then output.print("You travel alone."); return end
    output.print("Your party:")
    for _, char in ipairs(list) do
      local marker = (char.id == eng.state.party.active) and " (active)" or ""
      output.print("  " .. char.name .. marker)
    end
  end

  v.who = v.party

  v.help = function()
    output.print("Verbs: look, go <dir> / n s e w u d, take <item>, drop <item>, " ..
      "inventory [name] (i), examine <thing> (x), switch <name>, party (p), help, quit. " ..
      "Prefix any command with 'name:' to act as that party member.")
  end

  v.quit = function(eng) eng._running = false end

  return v
end

return M
