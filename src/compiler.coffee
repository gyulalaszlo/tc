_ = require 'underscore'
fs = require 'fs'
path = require 'path'
winston = require 'winston'
async = require 'async'

#parser_helper = require './parser_helper'
tree_parser = require './tree_parser/tree_parser'
#templates = require './templates'
builder = require './builder'

tc_packages = require './metadata'
util = require './util'

packaging = require './packaging'

MethodListResolver = require './resolver/method_list_resolver'
{resolve_type, replace_in_typelist, find_type_by_name, find_type_by_name_nocheck, type_name_with_extensions} = require './resolver/helpers'

class ScopeList
  constructor: ->
    @levels = [{}]
    @path = []

  add_level: (name)->
    @path.push name
    @levels.push {}

  remove_level: ->
    if @levels.length < 2
      throw new Error("Cannot remove any more levels from the ScopeList")
    @path.pop()
    @levels.pop()


  with_level: (name, callback)->
    @add_level(name)
    callback()
    @remove_level()

  current: -> @levels[ @levels.length - 1 ]

  get: (key)->
    i = @levels.length
    while i > 0
      i--
      return @levels[i][key] if @levels[i][key]
    null


# Compile a list of package. For options, see bin/tcc-parser
compile_packages = (package_list, options)->
  root = new packaging.Root( options.root )
  winston.info "Inside '#{path.normalize(root.dir)}'"
  tree_parser.parse_packages root, package_list, options, (parsed_packages)->
    package_name_list = _.pluck(parsed_packages, "name")
    winston.debug "Parsed #{parsed_packages.length} package(s): #{package_name_list.join(', ') }"

    # resolve the types in this package
    for pack in parsed_packages
      resolved = resolve_types pack, options
      package_dir = root.get( pack.name )
      package_dir.output_json( "_.normalized", resolved ) if options.saveNormalizedForm

      builder.build_package_files( resolved, package_dir, options )



# resolve any types in the package
resolve_types = (pack, options)->
  winston.debug "starting to resolve types of '#{pack.name}'"
  # create the normalized package data
  normalized_package = {name: pack.name, typelist: [], method_lists: [], expressions: []}
  # and cache it to local vars
  {typelist:typelist, method_lists:method_lists, expressions: expressions} = normalized_package

  scoped = new ScopeList
  scoped.with_level pack.name, ->
    resolve_typelist(pack, typelist, scoped)
    try
      new MethodListResolver( pack, normalized_package, scoped)
    catch err
      winston.error "Error while resolution: "
      winston.error err.stack, err

      normalized_package = {name: pack.name, typelist: [], method_lists: [], expressions: []}

  normalized_package



# resolve the root typelists entries in the package
resolve_typelist = (pack, typelist, scoped)->
  # forward-declare all local types so we can resolve them later
  for name, t of pack.types
    typelist.push { _type: "proxy", name: name, public: util.is_published(name) }


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
          resolved = resolve_type(t.original.name, scoped, typelist)
          replace_in_typelist typelist, name, { _type: "alias", name: name, original: resolved, docs: t.docs }

        # Classes and structs need their fields resolved
        when t._type in ['class', 'struct']
          fields = []
          for field in t.fields
            fields.push { name: field.name, type: resolve_type( field.type, scoped, typelist ), docs: field.docs }
          replace_in_typelist typelist, name, { _type: t._type, name: name, fields: fields, docs: t.docs }

        # Classes and structs need their fields resolved
        when t._type == 'interface'
          methods = []
          for meth in t.methods
            console.log meth
            methods.push
              is_virtual: true
              is_abstract: true
              name: meth.name
              returns: ( {type:resolve_type( r.name, scoped, typelist)} for r in meth.returns )
              args: ( {type:resolve_type( a.type, scoped, typelist), name: a.name} for a in meth.args )
              docs: meth.docs
            #methods.push { name: meth.name, type: resolve_type( field.type, scoped, typelist ), docs: field.docs }
          replace_in_typelist typelist, name, { _type: t._type, name: name, methods: methods, docs: t.docs }


module.exports =
  compile_packages: compile_packages

