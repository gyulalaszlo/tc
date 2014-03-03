_ = require 'underscore'
templates = require './templates'

types_tpl = require './templates/types'
class_tpl = require './templates/class'

build_package_files = (pack, path, options)->
  console.log build_types_file(pack, options).toString()
  build_class_files(pack, options)

build_types_file = (pack, options)->
  res = templates.run_c_tpl types_tpl, pack
  res._tokens


index_in_typelist = (typelist, name)->
  for k, i in typelist
    return i if k.name == name

  throw new Error("Cannot find type in typelist")

build_class_files = (pack, options)->
  for klass in _.where( pack.typelist, _type: 'class', public: true)
    # find the index in the typelist
    typelist_idx = index_in_typelist( pack.typelist, klass.name )
    # so we can filter our method sets
    method_lists = _.where( pack.method_lists, target: typelist_idx )
    # and run the template
    obj = {class: klass, package: pack, idx: typelist_idx, method_lists: method_lists}
    res = templates.run_c_tpl( class_tpl, obj)
    console.log res._tokens.toString()

module.exports =
  build_package_files: build_package_files
