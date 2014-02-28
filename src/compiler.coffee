_ = require 'underscore'

node = require './node_base'
parser_helper = require './parser_helper'

# register the node types
require './node_types'

TypesFileTemplates = require './templates/types_file'
ClassFileTemplates = require './templates/class_file'

parser_helper.with_parser "#{__dirname}/../grammar/tc.peg", (parser)->
  parser.parse_file "examples/test.tc", (res)->
    unit = node.autoconstruct(res)
    build_types_file( 'example', [unit] )
    build_class_files( 'example', [unit] )



build_types_file = (filename, units)->
  for unit in units
    for decl in unit.contents.declarations
      if decl.has_tag 'typedecl'
        console.log render_with_templates(TypesFileTemplates, decl.as)

build_class_files = (filename, units)->
  methods = {}
  klasses = {}
  each_matching_declaration units, "typedecl", (decl)->

    if decl.as.has_tag 'class'
      key = decl.name.text
      klasses[key] = render_with_templates(ClassFileTemplates, decl.as)

  each_matching_declaration units, "method_set", (decl)->
    key = decl.name.toString()
    methods[key] = [] unless methods[key]
    methods[key].push render_with_templates(ClassFileTemplates, decl)

  #console.log klasses
  #console.log JSON.stringify( methods)

  for k, v of klasses
    contents = ["class #{k}", "{"]
    contents.push klasses[k]
    contents.push methods[k].join("\n\n")
    contents.push "};"
    console.log contents.join("\n")



each_matching_declaration = (units, tag, callback)->
  for unit in units
    for decl in unit.contents.declarations
      if decl.has_tag tag
        callback(decl)


render_with_templates = (templates, node)->
  throw new Error("Unknown node: #{JSON.stringify(node)}") unless node && node.klass && node.klass.key
  key = node.klass.key
  tpl = templates[key]
  throw new Error("Cannot find template for #{key} (available templates: #{_.keys(templates)})") unless tpl
  o = tpl(node)
  for f in node.klass.fields
    field_regexp = new RegExp("%\{#{f}\}")
    continue unless o.match field_regexp
    # replace with the templated output
    local = node[f]
    local = [local] unless _.isArray(local)
    tpl_list = (render_with_templates( templates, child ) for child in local)
    o = o.replace field_regexp, tpl_list.join("")

  o





  #ALIAS: (a)->"typedef #{a.original.name} #{a.parent.name};"
  #STRUCT: (a)->"struct #{a.parent.name} %{layout};"
  #FIELDS: (a)->"{\n%{fields}}"
  #VAR: (a)->"  #{a.type.name} #{a.name};\n"
