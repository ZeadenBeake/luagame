local helpers = require "tests.helpers"
helpers.bootstrap()

local suites = {
  "tests.test_registry",
  "tests.test_state",
  "tests.test_parser",
  "tests.test_character",
  "tests.test_party",
  "tests.test_verbs",
  "tests.test_world",
  "tests.test_body",
  "tests.test_capabilities",
  "tests.test_encounter",
}

local total, failed = 0, 0
local failures = {}

for _, name in ipairs(suites) do
  local suite = require(name)
  local ordered = {}
  for k in pairs(suite) do ordered[#ordered + 1] = k end
  table.sort(ordered)
  for _, testName in ipairs(ordered) do
    total = total + 1
    local ok, err = pcall(suite[testName])
    if ok then
      io.write(".")
    else
      failed = failed + 1
      io.write("F")
      failures[#failures + 1] = name .. "." .. testName .. ": " .. tostring(err)
    end
    io.flush()
  end
end

io.write("\n")
for _, msg in ipairs(failures) do
  io.write("FAIL  " .. msg .. "\n")
end
io.write(string.format("\n%d run, %d failed\n", total, failed))
os.exit(failed == 0 and 0 or 1)
