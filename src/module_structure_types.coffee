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

# Mixins are the inverse concept of interfaces: they aim to provide 
# common functionality for structs of many different types.
#
#     // A Person requires a name and an age
#     type Person = mixin<AgeT:typename> {
#       name: CStr
#       age:  AgeT
#     }
#
# Later we can define methods on this mixin
#
#     public Person = {
#       Greet = ()-> { @sayWithName("hello"); }
#       IsAllowedToDrink = ()-> bool { return @age > (18 as AgeT); }
#       say = (what:CStr)-> { console.Log( "%s %s", what, @name ); }
#     }
# Now we need something to include this into:
#
#     type Guest = {
#       name: CStr
#       age: U32
#       // ...
#     }
# 
# To use this mixin, we need to use the "extend" keyword
#
#     extend <struct> with <mixin1>, [<mixin2>, <mixin3>]
#
# now calling extend will enable the calls on Guest instances 
# FOR THE CURRENT FILE
#
#     extend Guest with Person
#TC tries to figure out the correct template arguments
#     //
#
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

i32 = new TypeDeclaration {
  name: "I32"
  docs: null
  as: new CType {
    docs: null
    raw: "int32_t"
  }
}

console.log i32.toJSON()

