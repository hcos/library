if _G.js then
  return require "dkjson"
else
  return require "cjson" .new ()
end
