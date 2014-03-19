_        = require 'underscore'
_s       = require 'underscore.string'
async    = require 'async'

wrap_tpl = require './wrap_tpl'
util     = require './util'
Bench = require './bench'

class TemplateContext
  constructor: (@pack, @pack_dir, @options)->
    @context = {
      pack: @pack
      type_name: util.type_name
      published: _.chain( @pack.typelist ).where({ public: true })
      not_published: _.chain( @pack.typelist ).where({ public: false })
    }

  build_file: (output_file, template_name, data, callback_)->
    build_tpl template_name, data, (err, res)->
      return callback(err, res) if err
      @pack_dir.output_file output_file, res.toString(), (err)->
        callback(err)


    #callback = callback_ or data
    #wrap_tpl.load template_name, (tpl)=>
      #tpl_data = _.extend( {}, @context, data )
      #res =  tpl( tpl_data  )
      #@pack_dir.output_file output_file, res.toString(), (err)->
        #callback(err)

  build_tpl: (template_name, data, callback_)->
    callback = callback_ or data
    wrap_tpl.load template_name, (tpl)=>
      tpl_data = _.extend( {}, @context, data )
      res =  tpl( tpl_data  )
      callback( null, res )
      #@pack_dir.output_file output_file, res.toString(), (err)->
        #callback(err)


build_package_files = (pack, pack_dir, options, callback)->
  FILE_LIST = [
    { name: "#{_s.underscored pack.name}.cc"      , template: "package_impl" }
    { name: "#{_s.underscored pack.name}.h"       , template: "unbound_methods" }

    { name: "#{_s.underscored pack.name}_types.h" , template: "types" }
  ]
  templater_fn = (what, callback)->
    tpl = new TemplateContext( pack, pack_dir, options)
    tpl.build_tpl what.template, (err, res)->
      callback(err, _.extend( result: res, what )  )

  bench = new Bench("Generate C++ sources for package '#{pack.name}'")
  async.map FILE_LIST, templater_fn, (err, results)->
    return callback(err) if err
    bench.split("generation done...")
    # The write me out function
    write_fn = (what, callback)->
      pack_dir.output_file what.name, what.result, (err)->
        callback(err)

    # access the file system in a single queue
    async.each FILE_LIST, write_fn, (err)->
      bench.stop()
      callback(err, _.pluck( FILE_LIST, 'name' ))

  # build all the public class interface files
  # TODO: rewrite with wrap_tpl
  #build_class_files(pack, pack_dir, options)




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

module.exports =
  build_package_files: build_package_files
