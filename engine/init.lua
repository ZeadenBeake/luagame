local registry = require "engine.registry"
local state = require "engine.state"
local parser = require "engine.parser"
local output = require "engine.output"
local verbs = require "engine.verbs"
local party = require "engine.party"
local character = require "engine.character"
local body = require "engine.body"
local capabilities = require "engine.capabilities"
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
    _tickHooks = {},
    _scheduled = {},
    _running = false,
  }, Engine)
  return eng
end

function Engine:registerItem(def) registry.addItem(self.registry, def) end
function Engine:registerCreature(def) registry.addCreature(self.registry, def) end
function Engine:registerRoom(def) registry.addRoom(self.registry, def) end

function Engine:registerPart(def)
  assert(type(def) == "table", "part def must be a table")
  assert(type(def.id) == "string" and def.id ~= "", "part must have a non-empty string id")
  assert(body.SLOTS[def.slot], "part must declare a valid slot: " ..
    table.concat((function() local t={} for k in pairs(body.SLOTS) do t[#t+1]=k end return t end)(), ", "))
  assert(not self.registry.parts[def.id], "duplicate part id: " .. def.id)
  self.registry.parts[def.id] = def
end

function Engine:registerCapability(name, aggregation)
  capabilities.register(self.registry.capabilities, name, aggregation)
end

function Engine:registerCharacter(def)
  party.add(self.state.party, def)
  if def.body == "humanoid" then
    self:setupHumanoidBody(party.get(self.state.party, def.id))
  elseif type(def.body) == "function" then
    def.body(party.get(self.state.party, def.id), self)
  end
end

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

function Engine:setupHumanoidBody(char)
  for _, partDef in ipairs(body.HUMANOID_PARTS) do
    if not self.registry.parts[partDef.id] then
      self.registry.parts[partDef.id] = partDef
    end
    body.attach(char.body, partDef, self, char)
  end
end

function Engine:attachPart(char, partDefOrId)
  local def = type(partDefOrId) == "string" and self.registry.parts[partDefOrId] or partDefOrId
  assert(def and type(def.id) == "string", "invalid part def or unknown part id")
  return body.attach(char.body, def, self, char)
end

function Engine:detachPart(char, slotName, index)
  local instance = char.body.slots[slotName] and char.body.slots[slotName][index]
  if not instance then return false end
  return body.detach(char.body, slotName, index, self.registry.parts[instance.defId], self, char)
end

function Engine:setPartCondition(char, slotName, index, condition)
  local instance = char.body.slots[slotName] and char.body.slots[slotName][index]
  if not instance then return false end
  return body.setCondition(char.body, slotName, index, condition,
    self.registry.parts[instance.defId], self, char)
end

function Engine:queryCapability(char, capName)
  return capabilities.query(self.registry.capabilities, char,
    self.registry.parts, self.registry.items, capName)
end

function Engine:charHas(char, capName)
  local val = self:queryCapability(char, capName)
  return val ~= nil and val ~= false and val ~= 0
end

function Engine:partyHas(capName)
  for _, char in pairs(self.state.party.characters) do
    if char.body and self:charHas(char, capName) then return true end
  end
  return false
end

function Engine:onSave(fn) self._hooks.onSave = fn end
function Engine:onLoad(fn) self._hooks.onLoad = fn end
function Engine:onTurn(fn) self._hooks.onTurn = fn end

function Engine:tick()
  self.state.world.turn = self.state.world.turn + 1
  local turn = self.state.world.turn
  for _, char in pairs(self.state.party.characters) do
    if char.body then
      body.tickParts(char.body, self.registry.parts, self, char, turn)
    end
  end
  for _, fn in ipairs(self._tickHooks) do fn(self, turn) end
  local remaining = {}
  for _, entry in ipairs(self._scheduled) do
    if entry.at <= turn then
      entry.fn(self, turn)
    else
      remaining[#remaining + 1] = entry
    end
  end
  self._scheduled = remaining
end

function Engine:onTick(fn)
  assert(type(fn) == "function", "onTick requires a function")
  table.insert(self._tickHooks, fn)
end

function Engine:scheduleAt(turn, fn)
  assert(type(turn) == "number", "scheduleAt: turn must be a number")
  assert(type(fn) == "function", "scheduleAt: fn must be a function")
  table.insert(self._scheduled, { at = turn, fn = fn })
end

function Engine:scheduleIn(delta, fn)
  assert(type(delta) == "number" and delta > 0, "scheduleIn: delta must be a positive number")
  self:scheduleAt(self.state.world.turn + delta, fn)
end

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
  local previousActive
  if actorPart then
    local id = party.resolveByName(self.state.party, actorPart)
    if not id then
      output.print("No one named '" .. actorPart .. "' is in your party.")
      return false
    end
    if rest == "" then return true end
    previousActive = self.state.party.active
    party.setActive(self.state.party, id)
    input = rest
  end

  local verb, restArgs = parser.parse(input, self.verbs)
  local ok = true
  if not verb then
    if restArgs then output.print("I don't know the word '" .. restArgs .. "'.") end
    ok = false
  else
    local pok, err = pcall(self.verbs[verb], self, restArgs)
    if not pok then
      if previousActive then party.setActive(self.state.party, previousActive) end
      error(err, 0)
    end
    if self._hooks.onTurn then self._hooks.onTurn(self, verb, restArgs) end
  end

  if previousActive then party.setActive(self.state.party, previousActive) end
  return ok
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
M.body = body
M.capabilities = capabilities
M.cc = cc

return M
