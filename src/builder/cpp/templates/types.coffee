_ = require 'underscore'
_s = require 'underscore.string'
# Take a typelist and order it by depdendency, so that at any point in outputting
# that typelist, all the dependencies should be sorted out
makeTypeDeclarationList = (types)->
  dependencyList = ({ id: type.id, dependsOn: type.dependsOn } for type in types)

  return _.flatten( makeTypeDeclarationList__( dependencyList ) )
  console.log dependencyList
  _.pluck dependencyList, 'id'


# A type is solvable if it has no dependencies
isSolvable = (t)-> t.dependsOn.length == 0

# recursive helper for makeTypeDeclarationList
makeTypeDeclarationList__ = ( dependencyList, output=[] )->
  # Find the ones without dependencies
  solvables = _.chain( dependencyList ).filter( isSolvable ).pluck('id').value()
  # Add them to the output
  output.push solvables
  # remove them from the dependency list
  resolvedDependencyList = _.reject( dependencyList, (d)-> d.id in solvables )
  # and update the dependencies
  for d in resolvedDependencyList
    d.dependsOn = _.without( d.dependsOn, solvables... )

  # go to the next iteration
  if resolvedDependencyList.length > 0
    if solvables.length == 0
      throw new Error("Cannot resolve circular dependency between types #{JSON.stringify(resolvedDependencyList)}")
    makeTypeDeclarationList__( resolvedDependencyList, output )

  output

# ---------------------------------------------------------------------
#
docstring = (t)->
  return unless t.docs
  docLines = _s.lines( _s.strip( t.docs ) )
  switch docLines.length
    when 0 then # do nothing
    when 1 then @lines '', "/** #{ docLines[0] }*/"
    else
      @line ''
      @indent '/**', '*/', -> @lines docLines...


# Return a C-correct declaration of a named variable.
# like "uint32_t* data[6]".
variableDecl = (types, v)->
  typeData = typeExtension( types, types[v.type] )
  [
    typeData.before.join(''), cTypeName( types, v.type ), typeData.after.join(''), ' ',
    v.name, typeData.variable.join(''),
  ].join('')


# output a field of structured data
structField = (types, field)->
  @helper docstring, field
  @line variableDecl(types, field), ';'


# Output an interface method
interfaceMethod = (types, method)->
  @helper docstring, method

  returnType = ( cTypeName(types, types[t.type]) for t in method.returns )
  console.log returnType
  args = (variableDecl(types, a) for a in method.args )
  fieldType = [
    if returnType.length > 0 then returnType.join(',') else 'void',
    ' '
    '(*', method.name, ')'
    '('
    args.join(', ')
    ');'
  ].join('')

  @line fieldType

cTypeName = (types, t)->
  t = types[t] if _.isNumber(t)
  switch t._type
    when "ctype" then t.raw
    when 'extended' then extendedTypeName( types, t )
    else t.name


extendedTypeName = (types, t)->
  typeData = typeExtension( types, t )
  _.flatten( [typeData.before, cTypeName( types, typeData.base ), typeData.after] ).join('')


# Get the wrappers necessary for a type
typeExtension = (types, t, wrapper )->
  wrapper = wrapper or { base: null,  before:[], after: [], variable:[] }
  if t.extension
    switch t.extension._type
      when 'pointer' then wrapper.after.push '*'
      when 'reference' then wrapper.after.push '&'
      when 'array' then wrapper.variable.push "[#{ t.extension.size }]"
      else
        throw new Error("Unknown extension type: '#{t.extension._type}")

    typeExtension( types, types[t.base], wrapper )
  else
    wrapper.base = t
  return wrapper


# ---------------------------------------------------------------------
module.exports = ( pack )->
  types = pack.types
  @line "#pragma once"
  @line '#include "stdint.h"'

  @line "// Types for tc package: #{JSON.stringify pack.name}"

  @indent "namespace #{ pack.name } {", "}", ->

    for typeId in makeTypeDeclarationList( pack.types )
      type = pack.types[typeId]
      continue if type._type in ['extended', 'ctype']

      @helper docstring, type
      switch type._type
        # CTypes may need typedefs, but not if they are the same name
        when 'ctype' then
          #unless  type.raw == type.name
            #@lines "// use C type: #{type.raw} as #{type.name}", "typedef #{type.raw} #{type.name};"

        when 'alias'
          @lines "typedef #{cTypeName types, type.original} #{type.name};"

        when 'struct', 'class'
          @indent "struct #{type.name} {", "};", ->
            @mapHelper type.fields, structField, types

        when 'interface'
          methodsType = "#{type.name}Methods"
          @indent "struct #{methodsType} {", "};", ->
            @mapHelper type.methods, interfaceMethod, types
            @line '//'

          @indent "struct #{type.name} {", "};", ->
            @line "#{methodsType}* methods;"
            @line "void* data;"
        else
          @line "???", JSON.stringify(type)

      @line ''
