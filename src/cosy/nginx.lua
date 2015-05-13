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

  proxy_cache_path      cache   keys_zone=foreign:10m;
  lua_package_path      '%{path}';

  include /etc/nginx/mime.types;

  server {
    listen        localhost:%{port};
    listen        %{host}:%{port};
    server_name   %{name};
    charset       utf-8;
    index         index.html;
    default_type  application/octet-stream;
    access_log    access.log;

    location / {
      try_files $uri $uri/ /index.html =404;
    }

%{foreigns}

    location /lua {
      default_type  application/lua;
      content_by_lua '
        local name = ngx.var.uri:match "/lua/(.*)"
        local filename = package.searchpath (name, package.path)
        if filename then
          local file = io.open (filename, "r")
          ngx.say (file:read "*all")
          file:close ()
        else
          ngx.log (ngx.ERR, "failed to locate lua module: " .. name)
          ngx.status = 404
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

local foreign_template = [[
    location = /%{target} {
      proxy_cache foreign;
      proxy_pass  %{source};
      expires     1d;
    }
]]

function Nginx.start ()
  Nginx.directory = os.tmpname ()
  loader.logger.debug {
    _         = "nginx:directory",
    directory = Nginx.directory,
  }
  os.execute ([[
    rm -f %{diretory} && mkdir -p %{diretory}
  ]] % { diretory = Nginx.directory })
  local foreigns = {}
  for target in pairs (loader.configuration.dependencies) do
    local source = loader.configuration.dependencies [target]
    local url    = tostring (source._)
    if url:match "^http" then
      foreigns [#foreigns+1] = foreign_template % {
        target = target,
        source = url,
      }
    end
  end
  local configuration = configuration_template % {
    host      = loader.configuration.http.host._,
    port      = loader.configuration.http.port._,
    name      = loader.configuration.server.name._,
    foreigns  = table.concat (foreigns, "\n"),
    path      = package.path:gsub ("'", ""),
    wshost    = loader.configuration.websocket.host._,
    wsport    = loader.configuration.websocket.port._,
  }
  local file = io.open (Nginx.directory .. "/nginx.conf", "w")
  file:write (configuration)
  file:close ()
  os.execute ([[
    /usr/sbin/nginx -p %{directory} -c %{directory}/nginx.conf
  ]] % { directory = Nginx.directory })
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
