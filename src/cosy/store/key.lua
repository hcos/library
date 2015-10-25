return function (loader)

  local Mime = loader.require "mime"

  local Key = {}

  -- See RFC 4648
  function Key.encode (s)
    return select (1, Mime.b64 (s):gsub ("+", "-"):gsub ("/", "_"))
  end

  function Key.decode (s)
    return select (1, Mime.unb64 (s:gsub ("-", "+"):gsub ("_", "/")))
  end

  return Key

end
