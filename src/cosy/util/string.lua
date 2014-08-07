local string_mt = getmetatable ""

function string_mt:__mod (parameters)
  return self:gsub (
    '($%b{})',
    function (w)
      return parameters[w:sub(3, -2)] or w
    end
  )
end
