winston = require 'winston'
_ = require 'underscore'
util = require '../util'
ScopeList = require './scope_list'
MethodListResolver = require './method_list_resolver'
helpers = require './helpers'

# resolve any types in the package
resolve_types = (pack, options, callback)->
  # create the normalized package data
  normalized_package = {name: pack.name, typelist: [], method_lists: [], expressions: []}
  # and cache it to local vars
  {typelist:typelist, method_lists:method_lists, expressions: expressions} = normalized_package

  scoped = new ScopeList
  scoped.with_level pack.name, ->
    resolve_typelist(pack, typelist, scoped)
    err = null
    try
      new MethodListResolver( pack, normalized_package, scoped)
    catch e
      err = e
      normalized_package = {name: pack.name, typelist: [], method_lists: [], expressions: []}

    callback( e, normalized_package )


# replace a proxy type in the typelist
replace_in_typelist = (typelist, name, with_what)->
  for t,i in typelist
    # if the type matches, return the index in the typelist
    continue unless name == t.name
    unless t._type == 'proxy'
      throw new Error("Only proxy types can be replaced in the typelist, #{JSON.stringify(t)} isnt a proxy")
    _.extend typelist[i], with_what
    return
  throw new Error("Cannot find proxy type '#{name}' in typelist: [#{(t.name for t in typelist).join(', ')}]")


class Typelist
  constructor: (@typelist)->
    if _.isArray( @typelist )
      @arr = @typelist
      @parent = null
    else
      @parent = @typelist
      @arr = []
    @locals = []

  lookup: (name)->
    for t, i in @arr
      return {id:i, type:t} if name == t.name
    return @parent.lookup(name) if @parent
    return null

  # add a local type to the typelist
  add: (t)->


# resolve the root typelists entries in the package
resolve_typelist = (pack, typelist, scoped)->
  # forward-declare all local types so we can resolve them later
  for name, t of pack.types
    typelist.push { _type: "proxy", name: name, public: util.is_published(name) }


  typelist_wrapper = new Typelist( typelist )
  # go through each type and fill in the missing declrations
  # since the proxies go by name, we can replace by name
  for name, t of pack.types
    scoped.with_level name, ->
      switch
        # C types are already ok, no need to resolve
        when t._type == "ctype"
          replace_in_typelist typelist, name, { _type: "ctype", name: name, raw: t.c_name, docs: t.docs }

        # An alias should point to a resolved orignal
        when t._type == "alias"
          original_type_name = t.original
          resolved = helpers.resolve_type(t.original.name, scoped, typelist)
          replace_in_typelist typelist, name, { _type: "alias", name: name, original: resolved, docs: t.docs }

        # Classes and structs need their fields resolved
        when t._type in ['class', 'struct']
          #local_typelist = new Typelist( typelist_wrapper )
          # the templated types need to be created first
          if t.template
            for t_arg in t.template.args
              console.log t_arg
          # then add all the fields
          fields = []
          for field in t.fields
            fields.push { name: field.name, type: helpers.resolve_type( field.type, scoped, typelist ), docs: field.docs }
          replace_in_typelist typelist, name, { _type: t._type, name: name, fields: fields, docs: t.docs }

        # Classes and structs need their fields resolved
        when t._type == 'interface'
          methods = []
          for meth in t.methods
            methods.push
              is_virtual: true
              is_abstract: true
              name: meth.name
              returns: ( {type:helpers.resolve_type( r.name, scoped, typelist)} for r in meth.returns )
              args: ( {type:helpers.resolve_type( a.type, scoped, typelist), name: a.name} for a in meth.args )
              docs: meth.docs
            #methods.push { name: meth.name, type: helpers.resolve_type( field.type, scoped, typelist ), docs: field.docs }
          replace_in_typelist typelist, name, { _type: t._type, name: name, methods: methods, docs: t.docs }


module.exports =
  resolve_types: resolve_types
