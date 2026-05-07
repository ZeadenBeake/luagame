local h = require "tests.helpers"
local parser = require "engine.parser"

local T = {}

function T.tokenize_lowercases()
  local t = parser.tokenize("TAKE Brass Lantern")
  h.assertEq(t[1], "take")
  h.assertEq(t[2], "brass")
  h.assertEq(t[3], "lantern")
end

function T.parse_with_alias()
  local verbs = { north = function() end, _aliases = { n = "north" } }
  local v, rest = parser.parse("n", verbs)
  h.assertEq(v, "north")
  h.assertEq(#rest, 0)
end

function T.parse_unknown_verb()
  local verbs = { look = function() end, _aliases = {} }
  local v, bad = parser.parse("flarp", verbs)
  h.assertEq(v, nil)
  h.assertEq(bad, "flarp")
end

function T.resolve_by_alias()
  local reg = { lantern = { id = "lantern", name = "brass lantern", aliases = { "lamp" } } }
  local id = parser.resolveTarget({ "lamp" }, { "lantern" }, reg)
  h.assertEq(id, "lantern")
end

function T.resolve_by_partial_name()
  local reg = { lantern = { id = "lantern", name = "brass lantern" } }
  local id = parser.resolveTarget({ "brass" }, { "lantern" }, reg)
  h.assertEq(id, "lantern")
end

function T.resolve_returns_nil_when_not_in_pool()
  local reg = { lantern = { id = "lantern", name = "brass lantern" } }
  local id = parser.resolveTarget({ "lantern" }, {}, reg)
  h.assertEq(id, nil)
end

return T
