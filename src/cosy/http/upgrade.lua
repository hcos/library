local Upgrade = {}

function Upgrade.request (context)
  local what = context.request.headers.upgrade
  local ok, loaded = pcall (require, "cosy.http.upgrade." .. what)
  if not ok then
    context.response.status  = 501
    context.response.message = "Not Implemented"
    return
  end
  loaded (context)
end

function Upgrade.response ()
end

return Upgrade