local function ser(v, indent)
  indent = indent or ""
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
  if t == "table" then
    local parts = {}
    local nextIndent = indent .. "  "
    local isArray = true
    local n = 0
    for k in pairs(v) do
      n = n + 1
      if type(k) ~= "number" or k ~= n then isArray = false end
    end
    if isArray then
      for _, item in ipairs(v) do
        parts[#parts + 1] = nextIndent .. ser(item, nextIndent)
      end
    else
      for k, val in pairs(v) do
        local key
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          key = k
        else
          key = "[" .. ser(k) .. "]"
        end
        parts[#parts + 1] = nextIndent .. key .. " = " .. ser(val, nextIndent)
      end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
  end
  error("cannot serialize " .. t)
end

return function(v) return ser(v, "") end
