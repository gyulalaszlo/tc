_ = require 'underscore'

class Node

  has_tag: (name)->
    _.some( all[@klass.key].tags, (e)-> e == name )

all = {}

register = (klasses...)->
  for klass in klasses
    all[klass.key] = klass

autoconstruct = (data, parent=null)->
  key = data[0]
  klass = all[key]
  throw new Error("Cannot find Node class: '#{key}' data: #{JSON.stringify(data)}") unless klass
  node = new klass()
  node.klass = klass
  node.parent = parent
  for n, i in data[1..]
    res = switch
      when _.isArray( n)
        if n.length == 0 || _.isArray(n[0])
          (autoconstruct(el, node) for el in n)
        else
          autoconstruct(n, node)
      when _.isString n then n

    local_field = klass.fields[i]
    node[local_field] = res
  node

make_type = ( key, fields, methods={})->
  klass = ()->
  tags = if methods.tags then methods.tags else []
  _.extend klass, { key: key, fields: fields, tags: tags },
  _.extend klass.prototype, Node.prototype,  methods
  register( klass )

_.extend exports,
  Node: Node
  register: register
  make_type : make_type
  autoconstruct: autoconstruct





