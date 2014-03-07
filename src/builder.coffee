_ = require 'underscore'
_s = require 'underscore.string'
templates = require './templates'

types_tpl = require './templates/types'
class_tpl = require './templates/class'

package_impl = require './templates/package_impl'

wrap_tpl = require './wrap_tpl'

util = require './util'

build_package_files = (pack, pack_dir, options)->
  build_types_file(pack, pack_dir, options)
  build_class_files(pack, pack_dir, options)
  build_impl_file(pack, pack_dir, options)


build_types_file = (pack, pack_dir, options)->
  res = templates.run_c_tpl types_tpl, pack
  pack_dir.output_file "#{_s.underscored pack.name}_types.h", res._tokens.toString()
  #res._tokens

build_impl_file = (pack, pack_dir, options)->
  res = templates.run_c_tpl package_impl, pack
  pack_dir.output_file "#{_s.underscored pack.name}.cc", res._tokens.toString()

  wrap_tpl.load "package_impl", (tpl)->
    tpl_res =  tpl( pack: pack, type_name: util.type_name  )
    render_res = wrap_tpl.render( tpl_res )
    console.log JSON.stringify( tpl_res , null, 2  )
    console.log JSON.stringify( render_res , null, 2  )
  #ares._tokens


index_in_typelist = (typelist, name)->
  for k, i in typelist
    return i if k.name == name
  throw new Error("Cannot find type in typelist")

build_class_files = (pack, pack_dir, options)->
  for klass in _.where( pack.typelist, _type: 'class', public: true)
    # find the index in the typelist
    typelist_idx = index_in_typelist( pack.typelist, klass.name )
    # so we can filter our method sets
    method_lists = _.where( pack.method_lists, target: typelist_idx )
    # and run the template
    obj = {class: klass, package: pack, idx: typelist_idx, method_lists: method_lists}
    res = templates.run_c_tpl( class_tpl, obj)

    output_file_name = "#{_s.underscored klass.name}.h"
    pack_dir.output_file output_file_name, res._tokens.toString()
    #console.log res._tokens.toString()

module.exports =
  build_package_files: build_package_files
