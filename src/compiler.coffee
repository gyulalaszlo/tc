_ = require 'underscore'

node = require './node_base'
parser_helper = require './parser_helper'
templates = require './templates'

tc_packages = require './metadata'

# register the node types
require './node_types'

TypesFileTemplates = require './templates/types_file'
ClassFileTemplates = require './templates/class_file'

parser_helper.with_parser "#{__dirname}/../grammar/tc.peg", (parser)->
  parser.parse_file "examples/test.tc", (res)->
    unit = node.autoconstruct(res)
    #build_types_file( 'example', [unit] )
    build_class_files( 'example', [unit] )

    pack = tc_packages.from_units [unit]
    console.log pack




build_class_files = (filename, units)->
  meta = {}
  each_matching_declaration units, "typedecl", (decl)->
    if decl.as.has_tag 'class'
      key = decl.name.text
      meta[key] = { type: decl }

  each_matching_declaration units, "method_set", (decl)->
    key = decl.name.toString()
    meta[key].methods ||= []
    meta[key].methods.push decl

  for k, v of meta
    class_tpl = require './templates/class'
    res = templates.run_c_tpl class_tpl, meta[k]
    #console.log res.toString()
    console.log res._tokens.toString()

each_matching_declaration = (units, tag, callback)->
  for unit in units
    for decl in unit.contents.declarations
      if decl.has_tag tag
        callback(decl)



