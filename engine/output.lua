local cc = require "engine.cc"

local M = {}

local function wrap(text, width)
  local lines = {}
  for paragraph in (text .. "\n"):gmatch("(.-)\n") do
    if paragraph == "" then
      table.insert(lines, "")
    else
      local line = ""
      for word in paragraph:gmatch("%S+") do
        if #line == 0 then
          line = word
        elseif #line + 1 + #word <= width then
          line = line .. " " .. word
        else
          table.insert(lines, line)
          line = word
        end
      end
      if #line > 0 then table.insert(lines, line) end
    end
  end
  return lines
end

function M.print(text)
  local w = cc.size()
  for _, line in ipairs(wrap(tostring(text), w)) do
    cc.writeLine(line)
  end
end

function M.blank() cc.writeLine("") end

M.wrap = wrap
return M
