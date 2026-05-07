local registry = require "engine.registry"
local state = require "engine.state"
local parser = require "engine.parser"
local output = require "engine.output"
local verbs = require "engine.verbs"
local party = require "engine.party"
local character = require "engine.character"
local cc = require "engine.cc"

local Engine = {}
Engine.__index = Engine

local M = {}

function M.new()
  local eng = setmetatable({
    registry = registry.new(),
    state = state.new(),
    verbs = verbs.builtins(),
    _hooks = {},
    _running = false,
  }, Engine)
  return eng
end

function Engine:registerItem(def) registry.addItem(self.registry, def) end
function Engine:registerCreature(def) registry.addCreature(self.registry, def) end
function Engine:registerRoom(def) registry.addRoom(self.registry, def) end
function Engine:registerCharacter(def) party.add(self.state.party, def) end

function Engine:loadItems(path) registry.loadDataFile(self.registry, path, "item") end
function Engine:loadCreatures(path) registry.loadDataFile(self.registry, path, "creature") end
function Engine:loadRooms(path) registry.loadDataFile(self.registry, path, "room") end

function Engine:registerVerb(name, handler)
  assert(type(name) == "string" and name ~= "", "verb name must be a non-empty string")
  assert(type(handler) == "function", "verb handler must be a function")
  self.verbs[name] = handler
end

function Engine:registerVerbAlias(alias, target)
  self.verbs._aliases = self.verbs._aliases or {}
  self.verbs._aliases[alias] = target
end

function Engine:setStart(roomId)
  assert(self.registry.rooms[roomId], "unknown start room: " .. tostring(roomId))
  self.state.party.location = roomId
end

function Engine:placeItem(roomId, itemId) state.placeItem(self.state, roomId, itemId) end

function Engine:active() return party.active(self.state.party) end
function Engine:setActive(id) party.setActive(self.state.party, id) end
function Engine:partyMember(id) return party.get(self.state.party, id) end
function Engine:partyList() return party.list(self.state.party) end

function Engine:onSave(fn) self._hooks.onSave = fn end
function Engine:onLoad(fn) self._hooks.onLoad = fn end
function Engine:onTurn(fn) self._hooks.onTurn = fn end

function Engine:snapshot() return state.snapshot(self.state) end
function Engine:restore(snap) state.restore(self.state, snap) end

local function seedItemsIntoRooms(eng)
  for id, room in pairs(eng.registry.rooms) do
    if room.items then
      for _, itemId in ipairs(room.items) do
        state.placeItem(eng.state, id, itemId)
      end
    end
  end
end

function Engine:dispatch(input)
  if type(input) ~= "string" then return false end
  local actorPart, rest = input:match("^%s*([%w_]+)%s*:%s*(.*)$")
  if actorPart then
    local id = party.resolveByName(self.state.party, actorPart)
    if not id then
      output.print("No one named '" .. actorPart .. "' is in your party.")
      return false
    end
    party.setActive(self.state.party, id)
    input = rest
    if input == "" then return true end
  end

  local verb, restArgs = parser.parse(input, self.verbs)
  if not verb then
    if restArgs then output.print("I don't know the word '" .. restArgs .. "'.") end
    return false
  end
  self.verbs[verb](self, restArgs)
  if self._hooks.onTurn then self._hooks.onTurn(self, verb, restArgs) end
  return true
end

function Engine:run(opts)
  opts = opts or {}
  assert(self.state.party.active, "register at least one character before running")
  assert(self.state.party.location, "call setStart before running")
  if not opts.skipSeed then seedItemsIntoRooms(self) end
  if self._hooks.onLoad then self._hooks.onLoad(self) end
  self._running = true
  if opts.banner then output.print(opts.banner); output.blank() end
  if self.verbs.look then self.verbs.look(self) end
  while self._running do
    output.blank()
    local input = cc.readLine("> ")
    if not input then break end
    self:dispatch(input)
  end
  if self._hooks.onSave then self._hooks.onSave(self) end
end

M.parser = parser
M.output = output
M.state = state
M.registry = registry
M.party = party
M.character = character
M.cc = cc

return M
