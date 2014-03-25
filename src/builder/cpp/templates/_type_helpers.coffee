_ = require 'underscore'
_s = require 'underscore.string'

# Take a typelist and order it by depdendency, so that at any point in outputting
# that typelist, all the dependencies should be sorted out
exports.makeTypeDeclarationList = makeTypeDeclarationList = (types, filterBy)->
  dependencyList = ({ id: type.id, dependsOn: type.dependsOn } for type in types)

  return _.flatten( makeTypeDeclarationList__( dependencyList ) )
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
#
exports.varName = varName = (n)->
  switch n
    when 'typedef', 'typename', 'template', 'class', 'struct', 'if', 'else', 'do', 'while', 'case', 'switch', 'try', 'catch'
      return "#{n}_"
    else n



exports.docstring = docstring = (t)->
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
exports.variableDecl = variableDecl = (types, v)->
  typeData = typeExtension( types, types[v.type] )
  [
    typeData.before.join(''), cTypeName( types, v.type ), typeData.after.join(''), ' ',
    varName(v.name), typeData.variable.join(''),
  ].join('')


# output a field of structured data
exports.structField = structField = (types, field)->
  @helper docstring, field
  @line variableDecl(types, field), ';'

# Get a string with the return type for a method
exports.returnType = returnType = (types, returns)->
  ret = ( cTypeName(types, types[t.type]) for t in returns )
  if ret.length > 0 then ret.join(',') else 'void'

exports.argList = argList = (types, args, target=null)->
  a = (variableDecl(types, a) for a in args )
  # add the target in front if necessary
  a.unshift( variableDecl( types, target ) ) if target
  a


exports.interfaceMethodHeadline = interfaceMethodHeadline = (types, method)->
  returnType = ( cTypeName(types, types[t.type]) for t in method.returns )
  fieldType = [
    returnType( types, method.returns )
    ' '
    '(*', varName(method.name), ')'
    '('
    argList( types, method.args ).join(', ')
    ')'
  ].join('')



# Output an interface method
exports.interfaceMethod = interfaceMethod = (types, method)->
  @helper docstring, method
  headline = interfaceMethodHeadline( types, method )

  #returnType = ( cTypeName(types, types[t.type]) for t in method.returns )
  ##console.log returnType
  #args = (variableDecl(types, a) for a in method.args )
  #fieldType = [
    #if returnType.length > 0 then returnType.join(',') else 'void',
    #' '
    #'(*', method.name, ')'
    #'('
    #args.join(', ')
    #');'
  #].join('')

  @line headline, ';'


exports.cTypeName = cTypeName = (types, t)->
  t = types[t] if _.isNumber(t)
  switch t._type
    when "ctype" then t.raw
    when 'extended' then extendedTypeName( types, t )
    else varName(t.name)


exports.extendedTypeName = extendedTypeName = (types, t)->
  typeData = typeExtension( types, t )
  _.flatten( [typeData.before, cTypeName( types, typeData.base ), typeData.after] ).join('')



# Get the wrappers necessary for a type
exports.typeExtension = typeExtension = (types, t, wrapper )->
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


exports.typeDeclaration = typeDeclaration = (pack, types, typeId)->
  type = pack.types[typeId]
  return if type._type in ['extended', 'ctype']

  @helper docstring, type
  switch type._type
    # CTypes may need typedefs, but not if they are the same name
    when 'ctype' then
      #unless  type.raw == type.name
        #@lines "// use C type: #{type.raw} as #{type.name}", "typedef #{type.raw} #{type.name};"

    when 'alias'
      @lines "typedef #{cTypeName types, type.original} #{varName type.name};"

    when 'struct', 'class'
      @indent "struct #{varName type.name} {", "};", ->
        @mapHelper type.fields, structField, types

    when 'interface'
      methodsType = "#{varName type.name}Methods"
      @indent "struct #{methodsType} {", "};", ->
        @mapHelper type.methods, interfaceMethod, types
        @line '//'

      @indent "struct #{varName type.name} {", "};", ->
        @line "#{methodsType}* methods;"
        @line "void* data;"
    else
      @line "???", JSON.stringify(type)

  @line ''


exports.methodName = methodName = ( target, name)->
  return varName( name ) unless target
  "#{target.name}_#{name}"

exports.method = method = (types, m)->
  args = argList( types, m.args)
  args.unshift( "#{cTypeName( types, types[m.target] )}* _self" )  if m.target != -1
  #if m.target
    #argList( types, m.args, types[m.target] )

  o = [
    returnType( types, m.returns ), ' ',
    methodName( types[m.target], m.name )
    '('
    args.join(', ')
    ')'
  ].join('')


exports.methodWithBody = methodWithBody = (types, m)->
  @line method( types, m)
  @indent "{", "}", ->
    @line '//'
