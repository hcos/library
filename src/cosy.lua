require "cosy.connexion.js"

function window:do_something (model)

  model.form = {
    generator = {
      type = "form",
      name = "Generator",
      quantity = {
        type  = "text",
        name  = "# of dining philosophers?",
        value = 2,
        hint  = "a positive integer",
      },
      generate = {
        type = "button",
        name = "Generate!",
        clicked   = false,
        is_active = false,
      },
      close = {
        type = "button",
        name = "Close",
        clicked   = false,
        is_active = true,
      },
    },
  }

  model.think   = {}
  model.wait    = {}
  model.eat     = {}
  model.fork    = {}
  model.left    = {}
  model.right   = {}
  model.release = {}
  model.arcs    = {}

  model.number = 0

  model.think [1] = {
    type = "place",
    name = "thinking",
    marking = true,
    position = "4:30",
  }
  model.wait [1] = {
    type = "place",
    name = "waiting",
    marking = false,
    position = "2:30",
  }
  model.eat [1] = {
    type = "place",
    name = "eating",
    marking = false,
    position = "1:30",
  }
  model.fork [1] = {
    type = "place",
    name = "fork",
    marking = true,
    position = "3:15",
  }
  model.left [1] = {
    type = "transition",
    name = "take",
    position = "3.5:30",
  }

  model.arcs [1] = {
    type   = "arc",
    source = model.think [1],
    target = model.left  [1],
  }

end
