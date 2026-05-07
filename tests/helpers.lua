local M = {}

function M.bootstrap()
  package.path = "./?.lua;./?/init.lua;" .. package.path
  local mock = require "tests.cc_mock"
  package.loaded["engine.cc"] = mock
  return mock
end

function M.assertEq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertEq") .. ": expected " .. tostring(expected) ..
          ", got " .. tostring(actual), 2)
  end
end

function M.assertTrue(v, msg)
  if not v then error((msg or "assertTrue") .. ": expected truthy, got " .. tostring(v), 2) end
end

function M.assertContains(haystack, needle, msg)
  if not haystack:find(needle, 1, true) then
    error((msg or "assertContains") .. ": expected to find\n  " .. needle ..
          "\nin\n  " .. haystack, 2)
  end
end

function M.assertThrows(fn, pattern, msg)
  local ok, err = pcall(fn)
  if ok then error((msg or "assertThrows") .. ": expected error, none thrown", 2) end
  if pattern and not tostring(err):find(pattern) then
    error((msg or "assertThrows") .. ": error did not match " .. pattern ..
          "\ngot: " .. tostring(err), 2)
  end
end

return M
