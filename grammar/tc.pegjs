{
  merge_expr = function(group, name, left, right) {
    var result = left;
    for (var i = 0; i < right.length; i++) {
      part = right[i];
      // if we may have the op also
      result = { _type: name, _group: group,  a:result, b:part[part.length - 1 ] };
      if (part.length > 1) {
        result.op = part[0]
      }
    }
    return result;
  }

  // check for our PEGjs hack
  if (typeof peg$currPos == "undefined") { throw new ReferenceError("PEGjs hack for peg$currPos not working!"); }

  // hack to access peg$currPos for storing the positions of Identifier tokens
  function get_current_pos() {
    return { line: line(), column: column(), offset: offset()}
  }
}


start
  = package:PackageDecl contents:Contents ->{{ COMPILATION_UNIT with package, contents }}

NL_CHARS = [\n\r]

COMMENT "Comment"
  = "//" (!NL_CHARS . )*

WS_PART_NO_NL
  = COMMENT
  / [\t\v\f \u00A0\uFEFF]+

WS_PART
  = WS_PART_NO_NL
  / [\n\r]+

WS "whitespace"
  = WS_PART*

WS_NO_NL = WS_PART_NO_NL*

SE "Statement Terminator ';'"
  = WS_NO_NL [;\n\r] WS?

DocString "Documentation string"
  = '"""' text:(!'"""' ch:. { return ch; })* '"""' { return text.join(''); }
////////////////////////////////////////////////////////////////////////////////

PackageDecl "Package declaration"
  = "package" WS name:Identifier SE ->{{ PACKAGE with  name }}


Contents "Compilation Unit contents"
  = declarations:RootStatementList ->{{ CONTENTS with declarations }}


RootStatementList "Statement List"
  = RootStatementWithDocstring*

RootStatementWithDocstring
  = doc:(d:DocString WS { return d; })? r:RootStatement { r.docs = doc; return r; }


RootStatement "Root declaration statements"
  = TypeStatement
  / MethodList
  / GlobalMethodDeclaration

////////////////////////////////////////////////////////////////////////////////

TypeStatement "Type Statement"
  = "type" WS name:Identifier WS "=" WS definition:TypeDefinition_ SE ->{{ TYPEDECL with name, definition }}



TypeDefinition_ "Type Definition"
  = s:StructDefinition_ { return s; }
  / a:AliasDefinition_ { return a; }
  / c:CTypeDefinition_ { return c; }
  / d:ClassDefinition_ { return d; }
  / i:InterfaceDefinition_ { return i; }

////////////////////////////////////////////////////////////////////////////////

ClassDefinition_
  = "class" WS template:TemplatedStructure? fields:StructFieldList_
    ->{{ CLASS with fields, template }}

TemplatedStructure "Templated structured data (class or struct or interface)"
  = "<" WS  args:FunctionDeclarationArgumentList  ">" WS ->{{ TEMPLATE with args }}

////////////////////////////////////////////////////////////////////////////////

InterfaceDefinition_
  = "interface" WS method_list:InterfaceMethodList_ ->{{ INTERFACE with method_list }}

InterfaceMethodList_
  = "{" WS methods:InterfaceMethodDeclarationWithDocstring* "}" ->{{ METHODS with methods }}

InterfaceMethodDeclarationWithDocstring
  = doc:(d:DocString WS { return d; })? r:InterfaceMethodDeclaration { r.docs = doc; return r; }

InterfaceMethodDeclaration "Interface Method Declaration"
  = name:Identifier WS "=" WS func:FunctionDeclarationWithoutBody_ WS ->{{ METHOD with name, func }}


////////////////////////////////////////////////////////////////////////////////
StructDefinition_
  = "struct" WS template:TemplatedStructure ? fields:StructFieldList_ ->{{ STRUCT with fields, template }}


StructFieldList_
  = "{" WS fields:FieldDeclarationWithDocstring* "}" ->{{ FIELDS with fields }}

FieldDeclarationWithDocstring
  = doc:(d:DocString WS { return d; })? r:FieldDeclaration { r.docs = doc; return r; }

FieldDeclaration "Struct Field Declaration"
  = decl:VariableDeclaration_ SE { return decl; }

VariableDeclaration_ "Variable Declaration"
  = name:Identifier WS ':' WS  type:TypeName_ ->{{ VAR with type, name }}


////////////////////////////////////////////////////////////////////////////////

CTypeDefinition_ "A C type definition"
  = "C" WS c_name:TypeName_ ->{{ CTYPE with c_name  }}

////////////////////////////////////////////////////////////////////////////////

AliasDefinition_ "Alias"
  = "alias" WS original:TypeName_ ->{{ ALIAS with original }}

TypeName_ "Type Name"
  = name:Identifier
      extensions:( WS tap:TypeExtension { return tap;} )*
      ->{{ TYPE with name, extensions }}


TypeExtension "Array declaration part of types"
  =  "[" WS size:$DecimalIntegerLiteral WS "]" ->{{ type.ARRAY with size }}
  /  op:"*" ->{{ type.POINTER with op }}
  /  op:"&" ->{{ type.REFERENCE with op }}



////////////////////////////////////////////////////////////////////////////////

Identifier "identifier"
  = text:IdentifierName
  {
    return { _type: "IDENTIFIER", _group: "default", text: text.text, start: text.start, len: text.len };
  }

IdentifierName
  = start:IdentifierStart cont:IdentifierNameChars*
  {
    return {text:  start.char + cont.join(""), start: start.pos, len: (cont.length + 1)  };
  }

IdentifierStart = c:[a-zA-Z_] { return {char: c, pos: get_current_pos() }; }
IdentifierNameChars = [a-zA-Z0-9_]

////////////////////////////////////////////////////////////////////////////////

MethodList "Method list"
  = access:MethodAccessor WS name:Identifier
    WS "=" WS body:MethodListBody SE
    ->{{ METHODS with name, access, body }}

MethodListBody "Method List body"
  = "{" WS  decls:MethodDeclarationWithDocstring* "}" { return decls; }

MethodDeclarationWithDocstring
  = doc:(d:DocString WS { return d; })? r:MethodDeclaration { r.docs = doc; return r; }

MethodDeclaration "Method Declaration"
  = name:Identifier WS "=" WS func:FunctionDeclaration
    ->{{ METHOD with name, func }}

MethodAccessor "Method acess controll"
  = "public"
  / "protected"
  / "private"


FunctionDeclaration "Function declaration"
  = args:FunctionArgList "->" WS returns:FunctionReturnType body:FunctionBody
    ->{{ FUNC with args, body, returns }}

FunctionDeclarationWithoutBody_ "Function declaration"
  = args:FunctionArgList "->" WS returns:FunctionReturnType
    ->{{ FUNC with args, returns }}

FunctionArgList "Type list for function parameters/return values"
  = "(" WS args:FunctionDeclarationArgumentList ")" WS { return args; }

FunctionReturnType
  = list: TypeList { return list; }

FunctionDeclarationArgumentList
  = first:FunctionArgumentFirst WS more:FunctionArgumentMore*
    //{ return [ "ARGS", [first].concat( more ) ];}
    { return { _type: "ARGS", list: [first].concat( more ) };}
  / { return { _type: "ARGS", list: []} }

FunctionArgumentFirst
  = decl:VariableDeclaration_ ->{{ ARG with decl }}


FunctionArgumentMore
  = ',' WS decl:VariableDeclaration_ WS ->{{ ARG with decl }}


FunctionBody
  = "{" WS c:FunctionBodyContents  "}" WS { return c; }

////////////////////////////////////////////////////////////////////////////////

GlobalMethodDeclaration "Package global method declaration"
  = "func" WS name:Identifier WS "=" WS
    func:FunctionDeclaration
    ->{{ UNBOUND_METHOD with name, func }}

////////////////////////////////////////////////////////////////////////////////

TypeList "A list of types"
  = first:Typename_ WS more:MoreTypes* { return { _type:"TYPELIST", list: [first].concat(more) }; }
  / { return {_type:"TYPELIST", list:[] }; }

MoreTypes = "," WS more:Typename_ WS

Typename_ "Type name"
  = name:Identifier ->{{ TYPENAME with name }}

////////////////////////////////////////////////////////////////////////////////

FunctionBodyContents
  = statements:FunctionBodyElement* ->{{ BODY with statements }}


FunctionBodyElement
  = s:Statement_ SE { return s }

Statement_
  //= Expression_
  = s:ReturnStatement_
  / CreateAndAssignStatement_
  / expr:Expression_ ->{{ statement.EXPR with expr }}

ReturnStatement_
  = "return" WS expr:Expression_ ->{{ statement.RETURN with expr }}

CreateAndAssignStatement_
  = name:Identifier WS ":=" WS expr:Expression_ ->{{ statement.CASSIGN with name, expr }}

////////////////////////////////////////////////////////////////////////////////

{{ include expressions }}

{{ include literals }}
