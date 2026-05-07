local M = {}

local inputQueue = {}
local outputBuffer = {}

function M.write(s) outputBuffer[#outputBuffer + 1] = tostring(s) end
function M.writeLine(s) outputBuffer[#outputBuffer + 1] = tostring(s) .. "\n" end
function M.readLine() return table.remove(inputQueue, 1) end
function M.size() return 80, 24 end
function M.clear() outputBuffer = {} end
function M.sleep() end

function M.queueInput(...)
  for _, line in ipairs({ ... }) do inputQueue[#inputQueue + 1] = line end
end

function M.output() return table.concat(outputBuffer) end
function M.reset()
  inputQueue = {}
  outputBuffer = {}
end

return M
