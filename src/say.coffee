clc = require 'cli-color'
# Helper function for right-alignment
right_align = (what, len)->
  return what if what.length > len
  o = (' ' for i in [(what.length)..(len)])
  o.push what
  o.join('')


class Say

  set_options: (options)->
    @verbose = options.verbose
    @margin = options.margin || 20

  status_text: (what, text, color="cyan", textcolor="white")->
    "#{clc[color](right_align( what, @margin))} #{clc[textcolor](text)}"

  # Say something
  status: (what, text, color="cyan", textcolor="white")-> console.log @status_text(what, text, color, textcolor)

  # Say only if verbose is false
  status_v: (what, text)-> @status(what, text, "white", "blackBright") if @verbose

  error: (what, text)-> console.error @status_text( what, text, "red", "white" )

say = new Say

module.exports = say
