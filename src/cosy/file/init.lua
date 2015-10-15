local Value = require "cosy.value"

local File = {}

function File.encode (filname, data)
  local file = io.open (filname, "w")
  file:write (Value.expression (data))
  file:close ()
end

function File.decode (filename)
  local file, err = io.open (filename, "r")
  if not file then
    return nil, err
  end
  local data = file:read "*all"
  file:close ()
  return Value.decode (data)
end

return File
