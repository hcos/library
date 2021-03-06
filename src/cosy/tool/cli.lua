package.path    = package.path .. ";./?.lua"

local Loader    = require "cosy.loader.lua" {}
local I18n      = Loader.load "cosy.i18n"
local Layer     = Loader.require "cosy.formalism.layer"
local Arguments = Loader.require "argparse"
local Colors    = Loader.require "ansicolors"

local i18n = I18n.load {
  "cosy.tool",
}

local parser = Arguments () {
  name        = "cosy-tool",
  description = i18n ["tool:description"] % {},
  add_help    = {
    action = function () end
  },
}
parser:argument "tool" {
  description = i18n ["tool:tool:description"] % {},
}
parser:argument "parameters" {
  args = "*",
  description = i18n ["tool:parameters:description"] % {},
}
parser:require_command (false)
local toolname
do
  local arguments = { table.unpack (_G.arg)}
  local _exit = _G.os.exit
  _G.os.exit  = function () end
  repeat
    local ok, args = parser:pparse (arguments)
    if ok then
      toolname = args.tool
    elseif args:match "^unknown option" then
      local option = args:match "^unknown option '(.*)'$"
      for i = 1, # arguments do
        if arguments [i]:find (option) == 1 then
          table.remove (arguments, i)
          break
        end
      end
    else
      break
    end
  until ok
  -- End of UGLY hack.
  _G.os.exit = _exit
end

local loaded     = {}
for k in pairs (Layer.loaded) do
  loaded [k] = true
end

local mytool     = toolname and Layer.require (toolname) or nil
local parameters = {}
if mytool then
  local parameter_type = mytool [Layer.key.meta].parameter_type
  local seen = {}
  local function find_parameters (x)
    if getmetatable (x) == Layer.Proxy then
      if parameter_type <= x then
        parameters [x] = true
      end
      seen [x] = true
      for _, v in pairs (x) do
        if not seen [v] then
          find_parameters (v)
        end
      end
    end
  end
  find_parameters (mytool)
end

local help = parser
if mytool then
  parser = Arguments () {
    name        = "cosy-tool",
    description = i18n ["tool:description"] % {},
    add_help    = {
      action = function () print "here" end
    },
  }
  local command = parser:command (toolname) {
    description = mytool.description,
  }
  for key in pairs (parameters) do
    local convert
    if key.type == "number" then
      convert = tonumber
    elseif key.type == "string" then
      convert = tostring
    elseif key.type == "boolean" then
      convert = function (x)
        if x:lower () == "true" then
          return true
        elseif x:lower () == "false" then
          return false
        else
          assert (false)
        end
      end
    elseif key.type == "function" then
      convert = function (x)
        return assert (loadstring (x)) ()
      end
    elseif getmetatable (key.type) == Layer.Proxy then
      convert = function (x)
        if key.update then
          return Layer.require (x)
        else
          return {
            [Layer.key.refines] = { Layer.require (x) }
          }
        end
      end
    else
      assert (false)
    end
    command:option ("--" .. key.name) {
      description = key.description
                 .. (key.type and " (" .. tostring (key.type) .. ")" or ""),
      default     = key.default,
      required    = key.default and false or true,
      convert     = convert,
    }
  end
  parser:require_command (true)
  help = command
end

local ok, arguments = parser:pparse ()
if not ok then
  print (arguments)
  print (help:get_help ())
  os.exit (1)
end

local all_found = true
for key in pairs (parameters) do
  if not arguments [key.name] then
    print ("Argument " .. key.name .. " is mandatory.")
    all_found = false
  else
    local value = arguments [key.name]
    Layer.Proxy.replacewith (key, value)
  end
end

if not all_found then
  print (help:get_help ())
  os.exit (1)
end

Loader.scheduler.addthread (function ()
  mytool.run {
    model     = mytool,
    scheduler = Loader.scheduler,
  }
end)

Loader.scheduler.loop ()

do
  local directory = os.tmpname ()
  os.execute ([[
    rm -rf {{{directory}}}
    mkdir -p {{{directory}}}
  ]] % { directory = directory })
  for name, model in pairs (Layer.loaded) do
    if not loaded [name] then
      local package = name:gsub ("/", ".")
      local file = assert (io.open (directory .. "/" .. package, "w"))
      file:write (Layer.encode (model))
      file:close ()
    end
  end
  print (Colors ("%{green blackbg}" .. i18n ["tool:model-output"] % {
    directory = directory,
  }))
end
