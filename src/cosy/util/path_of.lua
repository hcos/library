local seq    = require "cosy.util.seq"
local tags   = require "cosy.util.tags"
local is_tag = require "cosy.util.is_tag"

local NAME = tags.NAME
local PATH = tags.PATH

local function path_of (path)
  local result
  for p in seq (path) do
    if type (p) == "string" then
      local i, j = string.find (p, "[_%a][_%w]*")
      if i == 1 and j == #p then
        result = result .. "." .. p
      else
        result = result .. "['" .. p .. "']"
      end
    elseif type (p) == "number" then
      result = result .. "[" .. tostring (p) .. "]"
    elseif type (p) == "boolean" then
      result = result .. "[" .. tostring (p) .. "]"
    elseif type (p) == "table" and is_tag (p) then
      result = result .. "[tags." .. p [NAME] .. "]"
    elseif type (p) == "table" and not result then
      result = tostring (p [NAME])
    elseif type (p) == "table" then
      result = result .. "[" .. path_of (p [PATH]) .. "]"
    else
      error ("cannot create patch from data type " .. type (p))
    end
  end
  return result
end

return path_of
