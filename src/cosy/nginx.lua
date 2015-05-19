local loader = require "cosy.loader"

local Nginx = {}

local configuration_template = [[
error_log   error.log;
pid         cosy.pid;

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
  lua_package_path      "%{path}";

  include /etc/nginx/mime.types;

  server {
    listen        localhost:%{port};
    listen        %{host}:%{port};
    server_name   "%{name}";
    charset       utf-8;
    index         index.html;
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    access_log    access.log;
    root          "%{www}";
    
    location / {
      try_files $uri $uri/ /index.html @foreigns;
    }

    location @foreigns {
      proxy_cache  foreign;
      expires      modified  1d;
      resolver     %{resolver};
      set $target "";
      access_by_lua '
        local redis   = require "nginx.redis" :new ()
        local ok, err = redis:connect ("%{redis_host}", %{redis_port})
        if not ok then
          ngx.log (ngx.ERR, "failed to connect to redis: ", err)
          return ngx.exit (500)
        end
        redis:select (%{redis_database})
        local target = redis:get ("foreigns:" .. ngx.var.uri)
        if not target or target == ngx.null then
          return ngx.exit (404)
        end
        ngx.var.target = target
      ';
      proxy_pass $target;
    }

    location /lua {
      default_type  application/lua;
      content_by_lua '
        local name = ngx.var.uri:match "/lua/(.*)"
        local filename = package.searchpath (name, "%{path}")
        if filename then
          local file = io.open (filename, "r")
          ngx.say (file:read "*all")
          file:close ()
        else
          ngx.log (ngx.ERR, "failed to locate lua module: " .. name)
          return ngx.exit (404)
        end
      ';
    }

    location /ws {
      proxy_pass          http://%{wshost}:%{wsport};
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

  }
}
]]

function Nginx.start ()
  Nginx.directory = os.tmpname ()
  loader.logger.debug {
    _         = "nginx:directory",
    directory = Nginx.directory,
  }
  os.execute ([[
    rm -f %{directory} && mkdir -p %{directory}
  ]] % { directory = Nginx.directory })
  local resolver
  do
    local file = io.open "/etc/resolv.conf"
    if not file then
      loader.logger.error {
        _ = "nginx:no-resolver",
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
  local configuration = configuration_template % {
    host           = loader.configuration.http.host._,
    port           = loader.configuration.http.port._,
    name           = loader.configuration.server.name._,
    redis_host     = loader.configuration.redis.host._,
    redis_port     = loader.configuration.redis.port._,
    redis_database = loader.configuration.redis.database._,
    path           = package.path,
    www            = loader.configuration.http.www._,
    wshost         = loader.configuration.websocket.host._,
    wsport         = loader.configuration.websocket.port._,
    resolver       = resolver,
  }
  local file = io.open (Nginx.directory .. "/nginx.conf", "w")
  file:write (configuration)
  file:close ()
  os.execute ([[
    %{nginx} -p %{directory} -c %{directory}/nginx.conf
  ]] % {
    nginx     = loader.configuration.http.nginx._,
    directory = Nginx.directory,
  })
end

function Nginx.stop ()
  os.execute ([[
    kill -QUIT $(cat %{directory}/cosy.pid) && rm -rf %{directory}
  ]] % { directory = Nginx.directory })
  Nginx.directory = nil
end

function Nginx.update ()
  os.execute ([[
    kill -HUP $(cat %{directory}/cosy.pid)
  ]] % { directory = Nginx.directory })
end

return Nginx
