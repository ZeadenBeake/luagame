package.path = package.path .. ";./?.lua;./?/init.lua"

local engine = require "engine"

local game = engine.new()

local here = (arg and arg[0] and arg[0]:match("(.*/)")) or "examples/cave/"
game:loadItems(here .. "data/items.lua")
game:loadCreatures(here .. "data/creatures.lua")
game:loadRooms(here .. "data/rooms.lua")

game:registerCharacter({
  id = "rin",
  name = "Rin",
  description = "A wiry traveler with quick hands and a sharper tongue.",
})
game:registerCharacter({
  id = "gar",
  name = "Gar",
  description = "Broad-shouldered and slow-spoken. Carries trouble like a burden.",
})

game:setStart("forest")

game:registerVerb("greet", function(eng, args)
  local room = eng.registry.rooms[eng.state.currentRoom]
  if not room or not room.creatures or #room.creatures == 0 then
    engine.output.print("There is no one to greet.")
    return
  end
  for _, id in ipairs(room.creatures) do
    local def = eng.registry.creatures[id]
    engine.output.print((def and def.name or id) .. " nods at you.")
  end
end)

local SAVE_PATH = "cave.save"

game:onSave(function(eng)
  local snap = eng:snapshot()
  if _G.textutils and _G.fs then
    local f = _G.fs.open(SAVE_PATH, "w")
    f.write(_G.textutils.serialize(snap))
    f.close()
  else
    local f = io.open(SAVE_PATH, "w")
    if f then
      f:write("return " .. require("examples.cave.serialize")(snap))
      f:close()
    end
  end
end)

game:onLoad(function(eng)
  if _G.textutils and _G.fs and _G.fs.exists(SAVE_PATH) then
    local f = _G.fs.open(SAVE_PATH, "r")
    local snap = _G.textutils.unserialize(f.readAll())
    f.close()
    if snap then eng:restore(snap) end
  end
end)

game:run({ banner = "== The Hermit's Cave ==\nA tiny example game.\nType 'help' for commands." })
