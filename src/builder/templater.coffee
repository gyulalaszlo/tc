_ = require 'underscore'
_s = require 'underscore.string'

INDENT_STR = "    "

class Templater

  constructor: (@filename)->
    @buffer = []
    @_indent = 0

  line: ( parts... )->
    @buffer.push { indent: @_indent, line: parts }

  lines: (lines...)->
    @line(l) for l in lines
    return null

  indent: (start, end, callback)->
    callback = callback or end or start
    @line( start ) if start
    @_indent += 1
    callback.call(@)
    @_indent -= 1
    @line( end ) if end


  helper: (helper, args...)->
    helper.call( @, args...)

  mapHelper: (arr, helper, args...)->
    helper.call( @, args...,el) for el in arr


  toString: ->
    o = for l in @buffer
      strippedLine = _s.strip(l.line.join(''))
      if strippedLine.length > 0
        _s.repeat( INDENT_STR, l.indent ) + strippedLine
      else
        ""

    o.join("\n")


# make a template function from the module
exports.makeTemplate = makeTemplate = (filename)->
  tpl = require "./#{filename}"
  return ( args... )->
    buffer = new Templater(filename)
    tpl.call( buffer, args... )
    buffer.toString()



exports.Templater = Templater
