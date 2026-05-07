local h = require "tests.helpers"
local party = require "engine.party"

local T = {}

local function newPartyWith(...)
  local p = party.new()
  for _, def in ipairs({ ... }) do party.add(p, def) end
  return p
end

function T.first_added_becomes_active()
  local p = newPartyWith({ id = "rin" }, { id = "gar" })
  h.assertEq(p.active, "rin")
end

function T.duplicate_id_errors()
  local p = newPartyWith({ id = "rin" })
  h.assertThrows(function() party.add(p, { id = "rin" }) end, "duplicate")
end

function T.set_active_validates()
  local p = newPartyWith({ id = "rin" })
  h.assertThrows(function() party.setActive(p, "ghost") end, "unknown")
end

function T.list_preserves_insertion_order()
  local p = newPartyWith({ id = "a" }, { id = "b" }, { id = "c" })
  local list = party.list(p)
  h.assertEq(list[1].id, "a")
  h.assertEq(list[2].id, "b")
  h.assertEq(list[3].id, "c")
end

function T.resolve_by_id_or_name_case_insensitive()
  local p = newPartyWith({ id = "rin", name = "Rin the Swift" })
  h.assertEq(party.resolveByName(p, "rin"), "rin")
  h.assertEq(party.resolveByName(p, "RIN"), "rin")
  h.assertEq(party.resolveByName(p, "Rin the Swift"), "rin")
  h.assertEq(party.resolveByName(p, "rin the swift"), "rin")
  h.assertEq(party.resolveByName(p, "ghost"), nil)
end

function T.remove_clears_active_to_next()
  local p = newPartyWith({ id = "rin" }, { id = "gar" })
  party.setActive(p, "rin")
  party.remove(p, "rin")
  h.assertEq(p.active, "gar")
end

function T.remove_returns_false_for_unknown()
  local p = newPartyWith({ id = "rin" })
  h.assertEq(party.remove(p, "ghost"), false)
end

function T.active_returns_character_object()
  local p = newPartyWith({ id = "rin", name = "Rin" })
  h.assertEq(party.active(p).name, "Rin")
end

return T
