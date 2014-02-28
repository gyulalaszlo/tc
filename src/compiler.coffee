_ = require 'underscore'

node = require './node_base'
parser_helper = require './parser_helper'

# register the node types
require './node_types'

TypesFileTemplates = require './templates/types_file'

parser_helper.with_parser "#{__dirname}/../grammar/tc.peg", (parser)->
  parser.parse_file "../example.sc", (res)->
    unit = node.autoconstruct(res)
    build_types_file( 'example', [unit] )



build_types_file = (filename, units)->
  types = []

  for unit in units
    for decl in unit.contents.declarations
      if decl.has_tag 'type'
        console.log render_with_templates(TypesFileTemplates, decl.as)


render_with_templates = (templates, node)->
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
