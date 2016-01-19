return function (loader)

  local Webclient = loader.load "cosy.webclient"
  local I18n      = loader.load "cosy.i18n"
  local i18n      = I18n.load {
    "cosy.webclient.headbar",
  }

  local HeadBar    = {}
  HeadBar.template = [[
    <nav class="navbar navbar-inverse navbar-fixed-top">
      <div class="container-fluid">
        <div class="navbar-header">
          <button type="button"
                  class="navbar-toggle collapsed"
                  data-toggle="collapse"
                  data-target="#navbar"
                  aria-expanded="false"
                  aria-controls="navbar">
            <span class="sr-only">{{headbar:toggle}}</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="#">{{title}}</a>
        </div>
        <div id="headbar:user"></div>
      </div>
    </nav>
    <script type="text/javascript">
      $(window).resize(function(){
        console.log ("resize");
        $(".main-content").css({"margin-top": (($(".navbar-fixed-top").height()) + 1 )+"px"});
      });
    </script>
  ]]

  return function (options)
    Webclient.run (function ()
      Webclient.show {
        where    = options.where,
        template = HeadBar.template,
        data     = {
          title = loader.client.server.information {}.name,
        },
        i18n     = i18n,
      }
      loader.window:eval [[
        $(".main-content").css({"margin-top": (($(".navbar-fixed-top").height()) + 1 )+"px"});
      ]]
      loader.load "cosy.webclient.authentication" {
        where = "headbar:user",
      }
    end)
  end

end
