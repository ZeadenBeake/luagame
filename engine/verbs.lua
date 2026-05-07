local output = require "engine.output"
local state = require "engine.state"
local parser = require "engine.parser"

local M = {}

local function look(eng)
  local room = eng.registry.rooms[eng.state.currentRoom]
  if not room then output.print("You are nowhere."); return end
  output.print(room.name or room.id)
  output.blank()
  if room.description then output.print(room.description) end
  local items = state.itemsInRoom(eng.state, room.id)
  if #items > 0 then
    output.blank()
    local names = {}
    for _, id in ipairs(items) do
      local def = eng.registry.items[id]
      names[#names + 1] = (def and def.name) or id
    end
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
    local room = eng.registry.rooms[eng.state.currentRoom]
    if not room or not room.exits or not room.exits[dir] then
      output.print("You can't go that way.")
      return
    end
    local target = room.exits[dir]
    if not eng.registry.rooms[target] then
      output.print("The way is blocked.")
      return
    end
    eng.state.currentRoom = target
    look(eng)
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

  v.inventory = function(eng)
    if #eng.state.inventory == 0 then output.print("You carry nothing."); return end
    output.print("You are carrying:")
    for _, id in ipairs(eng.state.inventory) do
      local def = eng.registry.items[id]
      output.print("  " .. ((def and def.name) or id))
    end
  end

  v.take = function(eng, args)
    local roomItems = state.itemsInRoom(eng.state, eng.state.currentRoom)
    local id = parser.resolveTarget(args, roomItems, eng.registry.items)
    if not id then output.print("You don't see that here."); return end
    local def = eng.registry.items[id]
    if def and def.takeable == false then
      output.print("You can't take that.")
      return
    end
    state.removeItemFromRoom(eng.state, eng.state.currentRoom, id)
    state.addToInventory(eng.state, id)
    output.print("Taken.")
  end

  v.drop = function(eng, args)
    local id = parser.resolveTarget(args, eng.state.inventory, eng.registry.items)
    if not id then output.print("You aren't carrying that."); return end
    state.removeFromInventory(eng.state, id)
    state.placeItem(eng.state, eng.state.currentRoom, id)
    output.print("Dropped.")
  end

  v.examine = function(eng, args)
    local pool = {}
    for _, id in ipairs(state.itemsInRoom(eng.state, eng.state.currentRoom)) do
      pool[#pool + 1] = id
    end
    for _, id in ipairs(eng.state.inventory) do pool[#pool + 1] = id end
    local id = parser.resolveTarget(args, pool, eng.registry.items)
    if id then
      local def = eng.registry.items[id]
      output.print(def.description or def.name or id)
      return
    end
    local room = eng.registry.rooms[eng.state.currentRoom]
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

  v.help = function()
    output.print("Verbs: look, go <dir>, north/south/east/west/up/down (n/s/e/w/u/d), take <item>, drop <item>, inventory (i), examine <thing> (x), help, quit.")
  end

  v.quit = function(eng) eng._running = false end

  return v
end

return M
