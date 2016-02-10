return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Default       = loader.load "cosy.configuration.layers".default
  local I18n          = loader.load "cosy.i18n"
  local Logger        = loader.load "cosy.logger"
  local Scheduler     = loader.load "cosy.scheduler"
  local Lfs           = loader.require "lfs"
  local Posix         = loader.require "posix"

  Configuration.load {
    "cosy.nginx",
    "cosy.redis",
  }

  local i18n   = I18n.load "cosy.nginx"
  i18n._locale = Configuration.locale

  local Nginx = {}

  local configuration_template = [[
error_log   error.log;
pid         {{{pid}}};
{{{user}}}

worker_processes 1;
events {
  worker_connections 1024;
}

http {
  tcp_nopush            on;
  tcp_nodelay           on;
  keepalive_timeout     65;
  types_hash_max_size   2048;

  proxy_temp_path       proxy;
  proxy_cache_path      cache   keys_zone=foreign:10m max_size=1g inactive=1d use_temp_path=off;
  lua_package_path      "{{{path}}}";
  lua_package_cpath     "{{{cpath}}}";

  gzip              on;
  gzip_min_length   0;
  gzip_types        *;
  gzip_proxied      no-store no-cache private expired auth;

  server {
    listen        {{{host}}}:{{{port}}};
    charset       utf-8;
    index         index.html;
    include       {{{nginx}}}/conf/mime.types;
    default_type  application/octet-stream;
    access_log    access.log;
    open_file_cache off;

    location / {
      add_header  Access-Control-Allow-Origin *;
      root        {{{source}}}/cosy/www;
      index       index.html;
      try_files   $uri $uri.html $uri/ /fallback/$uri;
    }

    location /fallback {
      add_header  Access-Control-Allow-Origin *;
      root        {{{prefix}}}/share/cosy/www;
      access_by_lua '
        ngx.var.target = ngx.var.uri:match "/fallback/(.*)"
      ';
      try_files     $target =404;
    }

    location = /setup {
      content_by_lua '
        local setup = require "cosy.nginx.setup"
        setup       = setup:gsub ("ROOT_URI", "http://" .. ngx.var.http_host)
        ngx.say (setup)
      ';
    }

    location /template {
      default_type  text/html;
      root          /;
      set           $target   "";
      access_by_lua '
        local name     = ngx.var.uri:match "/template/(.*)"
        local path     = "{{{source}}}/?.html;{{{source}}}/?/init.html"
        local filename, err = package.searchpath (name, path)
        if filename then
          ngx.var.target = filename
        else
          ngx.log (ngx.ERR, "failed to locate template: " .. name .. ", " .. tostring (err))
          return ngx.exit (404)
        end
      ';
      try_files     $target =404;
    }

    location /lua {
      default_type  application/lua;
      root          /;
      set           $target   "";
      access_by_lua '
        local name = ngx.var.uri:match "/lua/(.*)"
        local filename = package.searchpath (name, "{{{path}}}")
        if filename then
          ngx.var.target = filename
        else
          ngx.log (ngx.ERR, "failed to locate lua module: " .. name)
          return ngx.exit (404)
        end
      ';
      try_files     $target =404;
    }

    location /luaset {
      default_type  application/json;
      access_by_lua '
        ngx.req.read_body ()
        local body    = ngx.req.get_body_data ()
        local json    = require "cjson"
        local http    = require "resty.http"
        local data    = json.decode (body)
        local result  = {}
        for k, t in pairs (data) do
          local hc  = http:new ()
          local url = "http://127.0.0.1:{{{port}}}/lua/" .. k
          local res, err = hc:request_uri (url, {
            method = "GET",
            headers = {
              ["If-None-Match"] = type (t) == "table" and t.etag,
            },
          })
          if not res then
            ngx.log (ngx.ERR, "failed to request: " .. err)
            return
          end
          if res.status == 200 then
            local etag = res.headers.etag:match [=[^"([^"]+)"$]=]
            result [k] = {
              etag = etag,
            }
            if t == true
            or (type (t) == "table" and t.etag ~= etag)
            then
              result [k].lua = res.body
            end
          elseif res.status == 304 then
            result [k] = {}
          elseif res.status == 404 then
            result [k] = nil
          end
        end
        ngx.say (json.encode (result))
      ';
    }

    location /ws {
      proxy_pass          http://{{{wshost}}}:{{{wsport}}};
      proxy_http_version  1.1;
      proxy_set_header    Upgrade $http_upgrade;
      proxy_set_header    Connection "upgrade";
    }

  }
}
]]

  local function sethostname ()
    local handle = io.popen "hostname"
    local result = handle:read "*l"
    handle:close()
    Default.http.hostname = result
    Logger.info {
      _        = i18n ["nginx:hostname"],
      hostname = Configuration.http.hostname,
    }
  end

  function Nginx.configure ()
    if not Lfs.attributes (Configuration.http.directory, "mode") then
      Lfs.mkdir (Configuration.http.directory)
    end
    if not Configuration.http.hostname then
      sethostname ()
    end
    local configuration = configuration_template % {
      prefix         = loader.prefix,
      source         = loader.source,
      nginx          = Configuration.http.nginx,
      host           = Configuration.http.interface,
      port           = Configuration.http.port,
      pid            = Configuration.http.pid,
      wshost         = Configuration.server.interface,
      wsport         = Configuration.server.port,
      redis_host     = Configuration.redis.interface,
      redis_port     = Configuration.redis.port,
      redis_database = Configuration.redis.database,
      user           = Posix.geteuid () == 0 and ("user " .. os.getenv "USER" .. ";") or "",
      path           = package. path:gsub ("5%.2", "5.1") .. ";" .. package. path,
      cpath          = package.cpath:gsub ("5%.2", "5.1") .. ";" .. package.cpath,
    }
    local file = assert (io.open (Configuration.http.configuration, "w"))
    file:write (configuration)
    file:close ()
  end

  function Nginx.start ()
    Nginx.stop      ()
    Nginx.configure ()
    Nginx.bundle    ()
    os.execute ([[
      mkdir -p {{{dir}}}
    ]] % {
      dir = Configuration.http.directory .. "/logs"
    })
    if Posix.fork () == 0 then
      Posix.execp (Configuration.http.nginx .. "/sbin/nginx", {
        "-q",
        "-p", Configuration.http.directory,
        "-c", Configuration.http.configuration,
      })
    end
    Nginx.stopped = false
  end

  local function getpid ()
    local nginx_file = io.open (Configuration.http.pid, "r")
    if nginx_file then
      local pid = nginx_file:read "*a"
      nginx_file:close ()
      return pid:match "%S+"
    end
  end

  function Nginx.stop ()
    local pid = getpid ()
    if pid then
      Posix.kill (pid, 15) -- term
      Posix.wait (pid)
    end
    os.remove (Configuration.http.configuration)
    Nginx.directory = nil
    Nginx.stopped   = true
    os.remove (Configuration.http.bundle)
  end

  function Nginx.update ()
    Nginx.configure ()
    local pid = getpid ()
    if pid then
      Posix.kill (pid, 1) -- hup
    end
  end

  function Nginx.bundle ()
    os.remove (Configuration.http.bundle)
    Scheduler.addthread (function ()
      if Nginx.in_bundle or Configuration.dev_mode then
        return
      end
      Nginx.in_bundle = true
      local modules   = {}
      local function find (path, prefix)
        if path:match "%.$" then
          return
        end
        if  Lfs.attributes (path, "mode") == "file"
        and path:match "%.lua$"
        then
          local module = path:match "/([^/]+)%.lua$"
          if module == "init" then
            modules [#modules+1] = prefix
          else
            modules [#modules+1] = prefix and prefix .. "." .. module or module
          end
        elseif Lfs.attributes (path, "mode") == "directory"
        then
          local module = path:match "/([^/]+)$"
          local subprefix
          if prefix == nil then
            subprefix = false
          elseif prefix == false then
            subprefix = module
          else
            subprefix = prefix .. "." .. module
          end
          for sub in Lfs.dir (path) do
            find (path .. "/" ..sub, subprefix)
          end
        end
      end
      find (loader.lua_modules)
      table.sort (modules)
      local temp = os.tmpname ()
      Scheduler.execute ([[
        "{{{prefix}}}/bin/amalg.lua" -o "{{{temp}}}" -d {{{modules}}}
        if "{{{prefix}}}/bin/lua" "{{{temp}}}"; then cp "{{{temp}}}" "{{{target}}}"; fi
      ]] % {
        prefix  = loader.prefix,
        temp    = temp,
        target  = Configuration.http.bundle,
        modules = table.concat (modules, " "),
      })
      os.remove (temp)
      Nginx.in_bundle = nil
    end)
  end

  loader.hotswap.on_change.nginx = function ()
    Nginx.update ()
    Nginx.bundle ()
  end

  return Nginx

end
