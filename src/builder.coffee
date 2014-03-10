_ = require 'underscore'
_s = require 'underscore.string'
templates = require './templates'

types_tpl = require './templates/types'
class_tpl = require './templates/class'

package_impl = require './templates/package_impl'

wrap_tpl = require './wrap_tpl'

util = require './util'

class TemplateContext
  constructor: (@pack, @pack_dir, @options)->
    @context = {
      pack: @pack
      type_name: util.type_name
      published: _.chain( @pack.typelist ).where({ public: true })
      not_published: _.chain( @pack.typelist ).where({ public: false })
    }

  build_file: (output_file, template_name, data={})->
    wrap_tpl.load template_name, (tpl)=>
      tpl_data = _.extend( {}, @context, data )
      res =  tpl( tpl_data  )
      @pack_dir.output_file output_file, res.toString()

build_package_files = (pack, pack_dir, options)->
  tpl = new TemplateContext( pack, pack_dir, options)
  tpl.build_file  "#{_s.underscored pack.name}_types.h", "types"
  tpl.build_file  "#{_s.underscored pack.name}.cc", "package_impl"
  #build_types_file(pack, pack_dir, options)
  build_class_files(pack, pack_dir, options)
  #build_impl_file(pack, pack_dir, options)


build_types_file = (pack, pack_dir, options)->
  #res = templates.run_c_tpl types_tpl, pack
  #pack_dir.output_file "#{_s.underscored pack.name}_types.h", res._tokens.toString()

  wrap_tpl.load "types", (tpl)->
    res =  tpl( pack: pack, type_name: util.type_name  )
    pack_dir.output_file "#{_s.underscored pack.name}_types.h", res.toString()
    #pack_dir.output_file "#{_s.underscored pack.name}.cc", tpl_res.toString()

  #res._tokens

build_impl_file = (pack, pack_dir, options)->
  #res = templates.run_c_tpl package_impl, pack
  #pack_dir.output_file "#{_s.underscored pack.name}.cc", res._tokens.toString()

  wrap_tpl.load "package_impl", (tpl)->
    tpl_res =  tpl( pack: pack, type_name: util.type_name  )
    #console.log tpl_res.toString()
    pack_dir.output_file "#{_s.underscored pack.name}.cc", tpl_res.toString()


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
