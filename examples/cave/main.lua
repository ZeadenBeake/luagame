package.path = package.path .. ";./?.lua;./?/init.lua"

local engine = require "engine"

local game = engine.new()

local here = (arg and arg[0] and arg[0]:match("(.*/)")) or "examples/cave/"
game:loadItems(here .. "data/items.lua")
game:loadCreatures(here .. "data/creatures.lua")
game:loadRooms(here .. "data/rooms.lua")

game:registerCapability("flight", "all")

game:registerPart({
  id = "white_wing_left",
  slot = "wings",
  name = "left white wing",
  description = "A broad feathered wing, white as new snow.",
  provides = { flight = true },
  onAttach = function(_, char) engine.output.print(char.name .. " spreads their left wing.") end,
  onConditionChange = function(_, char, _, oldC, newC)
    if newC == "injured" then
      engine.output.print(char.name .. "'s left wing is injured -- flight lost.")
    end
  end,
})
game:registerPart({
  id = "white_wing_right",
  slot = "wings",
  name = "right white wing",
  description = "A broad feathered wing, white as new snow.",
  provides = { flight = true },
  onAttach = function(_, char) engine.output.print(char.name .. " spreads their right wing.") end,
})

game:registerCharacter({
  id = "rin",
  name = "Rin",
  description = "A wiry traveler with quick hands and a sharper tongue.",
  body = "humanoid",
})
game:registerCharacter({
  id = "gar",
  name = "Gar",
  description = "Broad-shouldered and slow-spoken. Carries trouble like a burden. Has wings.",
  body = function(char, eng)
    eng:setupHumanoidBody(char)
    eng:attachPart(char, "white_wing_left")
    eng:attachPart(char, "white_wing_right")
  end,
})

game:setStart("forest")

-- Wire encounter trigger after rooms are loaded
local cave = game.registry.rooms["cave_interior"]
cave.onEnter = function(eng)
  if eng.state.flags.spider_defeated then return end
  engine.output.print("A large cave spider drops from the ceiling, blocking the exit!")
  eng:startEncounter({
    banner = "=== Spider Encounter ===",
    actors = {
      { id = "rin" },
      { id = "gar" },
      { id = "spider", name = "Cave Spider",
        act = function(e, _)
          engine.output.print("The spider snaps its mandibles -- then retreats into a crevice.")
          e.state.flags.spider_defeated = true
          e:endEncounter("spider_fled")
        end,
      },
    },
    turnOrder = engine.turnorder.playersFirst,
    onEnd = function(_, reason)
      if reason == "spider_fled" then
        engine.output.print("The way is clear.")
      end
    end,
  })
end

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
