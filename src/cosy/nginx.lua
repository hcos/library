local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"

Configuration.load {
  "cosy.nginx",
  "cosy.redis",
}

local i18n   = I18n.load "cosy.nginx"
i18n._locale = Configuration.locale [nil]

local Nginx = {}

local configuration_template = [[
error_log   error.log;
pid         {{{pidfile}}};

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
  proxy_cache_path      cache   keys_zone=foreign:10m;
  lua_package_path      "{{{path}}}";

  include /etc/nginx/mime.types;

  gzip              on;
  gzip_min_length   0;
  gzip_types        *;
  gzip_proxied      no-store no-cache private expired auth;

  server {
    listen        localhost:{{{port}}};
    listen        {{{host}}}:{{{port}}};
    server_name   "{{{name}}}";
    charset       utf-8;
    index         index.html;
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    access_log    access.log;
    root          "{{{www}}}";

    location / {
      try_files $uri $uri/ $uri/index.html @foreigns;
    }

    location @foreigns {
      proxy_cache  foreign;
      expires      modified  1d;
      resolver     {{{resolver}}};
      set $target "";
      access_by_lua '
        local redis   = require "nginx.redis" :new ()
        local ok, err = redis:connect ("{{{redis_host}}}", {{{redis_port}}})
        if not ok then
          ngx.log (ngx.ERR, "failed to connect to redis: ", err)
          return ngx.exit (500)
        end
        redis:select ({{{redis_database}}})
        local target = redis:get ("foreign:" .. ngx.var.uri)
        if not target or target == ngx.null then
          return ngx.exit (404)
        end
        ngx.var.target = target
      ';
      proxy_pass $target;
    }

    location /lua {
      default_type  application/lua;
      root          /;
      set $target   "";
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

    location /ws {
      proxy_pass          http://{{{wshost}}}:{{{wsport}}};
      proxy_http_version  1.1;
      proxy_set_header    Upgrade $http_upgrade;
      proxy_set_header    Connection "upgrade";
    }

    location /hook {
      content_by_lua '
        local temporary = os.tmpname ()
        local file      = io.open (temporary, "w")
        file:write [==[
          git pull --quiet --force
          luarocks install --local --force --only-deps cosyverif
          for rock in $(luarocks list --outdated --porcelain | cut -f 1)
          do
          luarocks install --local --force ${rock}
          done
          rm --force $0
        ]==]
        file:close ()
        os.execute ("bash " .. temporary .. " &")
      ';
    }

    location /upload {
      limit_except               POST { deny all; }
      client_body_temp_path      uploads/;
      client_body_buffer_size    128K;
      client_max_body_size       10240K;
      content_by_lua '
        ngx.req.read_body ()
        local redis   = require "nginx.redis" :new ()
        local ok, err = redis:connect ("{{{redis_host}}}", {{{redis_port}}})
        if not ok then
          ngx.log (ngx.ERR, "failed to connect to redis: ", err)
          return ngx.exit (500)
        end
        redis:select ({{{redis_database}}})
        local id = redis:incr "#upload"
        local key = "upload:" .. tostring (id)
        redis:set (key, ngx.req.get_body_data ())
        redis:expire (key, 300)
        ngx.header ["Cosy-Avatar"] = key
      ';
    }

  }
}
]]

function Nginx.configure ()
  local resolver
  do
    local file = io.open "/etc/resolv.conf"
    if not file then
      Logger.error {
        _ = i18n ["nginx:no-resolver"],
      }
    end
    local result = {}
    for line in file:lines () do
      local address = line:match "nameserver%s+(%S+)"
      if address then
        result [#result+1] = address
      end
    end
    file:close ()
    resolver = table.concat (result, " ")
  end
  os.execute ([[
    if [ ! -d {{{directory}}} ]
    then
      mkdir {{{directory}}}
    fi
    if [ ! -d {{{uploads}}} ]
    then
      mkdir {{{uploads}}}
    fi
  ]] % {
    directory = Configuration.http.directory [nil],
    uploads   = Configuration.http.uploads   [nil],
  })
  local configuration = configuration_template % {
    host           = Configuration.http.interface   [nil],
    port           = Configuration.http.port        [nil],
    www            = Configuration.http.www         [nil],
    uploads        = Configuration.http.uploads     [nil],
    pidfile        = Configuration.http.pid         [nil],
    name           = Configuration.server.name      [nil],
    wshost         = Configuration.server.interface [nil],
    wsport         = Configuration.server.port      [nil],
    redis_host     = Configuration.redis.interface  [nil],
    redis_port     = Configuration.redis.port       [nil],
    redis_database = Configuration.redis.database   [nil],
    path           = package.path,
    resolver       = resolver,
  }
  local file = io.open (Configuration.http.configuration [nil], "w")
  file:write (configuration)
  file:close ()
end

function Nginx.start ()
  os.execute ([[
    rm -f {{{directory}}} && mkdir -p {{{directory}}}
  ]] % {
    directory = Configuration.http.directory [nil],
  })
  Nginx.configure ()
  os.execute ([[
    {{{nginx}}} -p {{{directory}}} -c {{{configuration}}} 2>> {{{error}}}
  ]] % {
    directory     = Configuration.http.directory     [nil],
    nginx         = Configuration.http.nginx         [nil],
    configuration = Configuration.http.configuration [nil],
    error         = Configuration.http.error         [nil],
  })
end

function Nginx.stop ()
  os.execute ([[
    [ -f {{{pidfile}}} ] && {
      kill -QUIT $(cat {{{pidfile}}})
    }
  ]] % {
    pidfile = Configuration.http.pid [nil],
  })
  os.execute ([[
    rm -rf {{{directory}}}
  ]] % {
    directory = Configuration.http.directory [nil],
  })
  Nginx.directory = nil
end

function Nginx.update ()
  Nginx.configure ()
  os.execute ([[
    [ -f {{{pidfile}}} ] && {
      kill -HUP $(cat {{{pidfile}}})
    }
  ]] % {
    pidfile = Configuration.http.pid [nil],
  })
end

return Nginx
