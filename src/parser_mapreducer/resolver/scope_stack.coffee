_ = require 'underscore'

class ScopeLevel
  constructor: (@name)->
    @values = {}
  set: (key, val)-> @values[key] = val
  get: (key)-> @values[key]
  has: (key)-> @values[key] != undefined

class ScopeStack
  constructor: (@parent, @types, @methods, @target)->
    @levels = []
    @target = @target ? @parent.target if @target

  push: (name)-> @levels.push new ScopeLevel(name)
  pop: ()->
    throw new Error("Tried to pop empty scope") unless @levels.length > 0
    @levels.pop()

  current: -> @levels[ @levels.length - 1 ]

  # Set something to be visible from the levels bellow this one
  set: (key, val)-> @current().set( key, val )
  # Does this scope stack have the given key
  has: (key)->
    for l in @levels
      return true if l.has( key )
    # call the parent if necessary
    return @parent.has(key) if @parent
    false
  # Get a key from the scope stack
  get: (key)->
    for l in @levels
      return l.get( key) if l.has( key )
    # call the parent if necessary
    return @parent.get(key) if @parent
    undefined


  type: (id)->
    local = _.findWhere( @types, id: id )
    return local if local
    return @parent.type(id) if @parent
    return null

  path: ->
    o = (l.name for l in @levels).join('/')
    o = @parent.path() + '/' + o if @parent
    o


  variables: ()->
    o = for l in @levels
      _.clone l.values
    return o unless @parent
    @parent.variables().concat o

  #error: (attrs={})->
    #_.defaults( attrs,
      #inside: @path()
      #start: null
    #)
    #msg = [
      #"(inside:#{})
    #]
    #throw new Error [

    #]



module.exports = ScopeStack
