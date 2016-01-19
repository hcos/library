return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  if not Default.webclient then
    Default.webclient = {}
  end

  Default.webclient.navigation = {}

  Default.webclient.navigation.navbar = [[
  ]]

  Default.webclient.navigation.navbar = [[
    <nav class="navbar navbar-inverse navbar-fixed-top">
      <div class="container-fluid">
        <div class="navbar-header">
          <button type="button"
                  class="navbar-toggle collapsed"
                  data-toggle="collapse"
                  data-target="#navbar"
                  aria-expanded="false"
                  aria-controls="navbar">
            <span class="sr-only">{{toggle-navbar}}</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="#">{{title}}</a>
        </div>
        <form class="navbar-form navbar-right">
          <input type="text"
                 class="form-control"
                 placeholder="Search..." />
        </form>
        <ul class="nav navbar-nav navbar-right">
          <li><a href="#"><span class="glyphicon glyphicon-user"  ></span>{{sign-up}}</a></li>
          <li><a href="#"><span class="glyphicon glyphicon-log-in"></span>{{log-in}} </a></li>
        </ul>
      </div>
    </nav>
  ]]


end
