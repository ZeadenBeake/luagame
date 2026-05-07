local inputs = { "look", "take lantern", "north", "inventory", "quit" }
local i = 0
_G.read = function()
  i = i + 1
  local line = inputs[i]
  if line then print("> " .. line) end
  return line
end

package.path = "/proj/?.lua;/proj/?/init.lua;" .. package.path

local ok, engine = pcall(require, "engine")
if not ok then
  print("FAIL: could not require engine: " .. tostring(engine))
  os.shutdown()
end

local g = engine.new()
g:loadItems("/proj/examples/cave/data/items.lua")
g:loadCreatures("/proj/examples/cave/data/creatures.lua")
g:loadRooms("/proj/examples/cave/data/rooms.lua")
g:registerCharacter({ id = "rin", name = "Rin" })
g:setStart("forest")

g:run()

local hasLantern = false
local rin = g:active()
for _, id in ipairs(rin.inventory) do
  if id == "lantern" then hasLantern = true end
end

if g.state.party.location == "cave_entrance" and hasLantern then
  print("CC_SMOKE_OK")
else
  print("CC_SMOKE_FAIL room=" .. tostring(g.state.currentRoom) ..
        " lantern=" .. tostring(hasLantern))
end

os.shutdown()
