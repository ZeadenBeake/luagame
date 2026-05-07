local M = {}

local hasTerm = (type(_G.term) == "table" and type(_G.term.write) == "function")

if hasTerm then
  function M.write(s) _G.term.write(tostring(s)) end
  function M.writeLine(s) print(tostring(s)) end
  function M.readLine(prompt)
    if prompt then _G.term.write(prompt) end
    return _G.read()
  end
  function M.size() return _G.term.getSize() end
  function M.clear() _G.term.clear(); _G.term.setCursorPos(1, 1) end
  function M.sleep(s) _G.sleep(s) end
else
  function M.write(s) io.write(tostring(s)) end
  function M.writeLine(s) io.write(tostring(s)); io.write("\n") end
  function M.readLine(prompt)
    if prompt then io.write(prompt); io.flush() end
    return io.read("*l")
  end
  function M.size() return 80, 24 end
  function M.clear() io.write("\27[2J\27[H") end
  function M.sleep(s) os.execute("sleep " .. tostring(tonumber(s) or 0)) end
end

return M
