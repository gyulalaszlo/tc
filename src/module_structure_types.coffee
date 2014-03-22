Struct = require './struct'

# Type declarations, these classes should not encapsulate any behaviour

class Identifier extends Struct
  requires: { start: 'SourcePosition', length: 'number', text: 'string' }

class TypeDeclaration extends Struct
  requires: { name: 'Identifier', docs: 'string', as: 'Type' }

class CType extends Struct
  requires: { raw: 'StringLiteral' }

class Alias extends Struct
  requires: { original: 'Type' }

class Struct extends Struct
  requires: { fields: '[]Field' }

class Class extends Struct
  requires: { fields: '[]Field' }

class Mixin extends Struct
  requires: { fields: '[]Field' }

class Interface extends Struct
  requires: { methods: '[]MethodDeclaration' }

class MethodDeclaration extends Struct
  requires:
    name: 'Identifier'
    args: '[]MethodArgument'
    returns: '[]Type'

class MethodArgument extends Struct
  requires:
    name: 'Identifier'
    type: 'Type'
    
# ----------------------------------------
#
# ## Method lists

class MethodSet extends Struct
  requires:
    target: 'Type'
    name: 'Identifier'
    methods: '[]Method'

class Method extends Struct
  requires:
    decl: 'MethodDeclaration'
    body: 'StatementList'


module.exports =
  Identifier: Identifier
  TypeDeclaration: TypeDeclaration
  CType: CType
  Alias: Alias
  Struct: Struct
  Class: Class
  Mixin: Mixin
  Interface: Interface
  MethodDeclaration: MethodDeclaration
  MethodArgument: MethodArgument
  MethodSet: MethodSet
  Method: Method


