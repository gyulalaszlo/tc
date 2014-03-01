_ = require 'underscore'

class Package
  
  constructor: (@name)->
    @symbols = {}
    @types = {}
  
  classes: ->
    #_.where( @symbols, type:

class TypeBase

class Class extends TypeBase
  constructor: (@package, @name)->

class Struct extends TypeBase
  constructor: (@package, @name)->

class Alias extends TypeBase
  constructor: (@package, @name)->


type_base_map = CLASS: Class, STRUCT: Struct, ALIAS: Alias

# Get a units package name
package_name_for_unit = (unit)->
  unit.package.name.text



make_type_instance = (pkg, name, decl)->
  key = decl.as.klass.key
  klass = type_base_map[key]
  throw new Error("Unknown type to instantiate: #{key}") unless klass
  return new klass(pkg, name)
  #console.log name, decl.as
  #switch decl.as.klass.key
    #when 'CLASS' then new Class(name)
    #when 'STRUCT' then new Struct(name)
    #when 'STRUCT' then new Struct(name)
    #else

add_declarations_to_package = (pkg, declarations)->
  # Add the declarations
  for decl in declarations
    switch decl.klass.key
      when 'TYPEDECL'
        #console.log decl
        type_name = decl.name.text
        pkg.types[type_name] = make_type_instance( pkg, type_name, decl )



package_from_units = (units)->
  # fail on empty packages
  return null if units.length == 0
  # create the package
  package_name = package_name_for_unit units[0]
  pkg = new Package(package_name)
  # 
  for unit in units
    # check if the unit is in the valid package
    unit_package_name = package_name_for_unit unit
    unless unit_package_name == package_name
      throw new Error("Package name '#{unit_package_name}' differs from '#{package_name}'")
    # We are sure we have the right package
    add_declarations_to_package( pkg, unit.contents.declarations )

  pkg

module.exports =
  Class: Class
  Package: Package
  from_units: package_from_units
