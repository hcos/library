             require "cosy.util.string"
local Tag  = require "cosy.tag"
local Data = require "cosy.data"

local function dump (x)
  if x == nil then
    return "nil"
  elseif type (x) == "boolean" then
    return tostring (x)
  elseif type (x) == "number" then
    return tostring (x)
  elseif type (x) == "string" then
    return x:quote ()
  elseif type (x) == "table" and Tag.is (x) then
    return tostring (x)
  elseif type (x) == "table" and Data.is (x) then
    return tostring (x)
  elseif type (x) == "table" then
    local result = {}
    for k, v in pairs (x) do
      if type (k) == "string" and k:is_identifier () then
        result [#result + 1] = "${k} = ${v}" % {
          k = k,
          v = dump (v)
        }
      else
        result [#result + 1] = "[ ${k} ] = ${v}" % {
          k = dump (k),
          v = dump (v),
        }
      end
    end
    return "{ " .. table.concat (result, ", ") .. " }"
  elseif type (x) == "function" then
    return string.dump (x)
  else
    error ("Unable to dump x for data type ${type}." % {
      type = type (x)
    })
  end
end

return dump
