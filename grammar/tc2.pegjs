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

  // hack to access peg$currPos for storing the positions of Identifier tokens
  function get_current_pos() {
    return { line: line(), column: column(), offset: offset()}
  }

  // the name of the package
  var packageName = '';

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
  = "package" WS name:Identifier SE
  {
    packageName = name.text;
  }


Contents "Compilation Unit contents"
  = declarations:RootStatementList { return declarations; }


RootStatementList "Statement List"
  = RootStatementWithDocstring*

RootStatementWithDocstring
  = doc:(d:DocString WS { return d; })? r:RootStatement
  {
    // the docs for unbound methods should be added to the
    // first (only) method in the method set, and not the
    // method set itself
    if (r._type == "methodset" && r.target == null)
    {
      r.methods[0].docs = doc;
    }
    else
    {
      r.docs = doc;
    }
    // assign the package name.
    // TODO: do this at token creation time
    r.package = packageName;
    return r;
  }


RootStatement "Root declaration statements"
  = TypeStatement
  / MethodList
  / GlobalMethodDeclaration

////////////////////////////////////////////////////////////////////////////////

TypeStatement "Type Statement"
  = "type" WS name:Identifier WS "=" WS definition:TypeDefinition_ SE
  {
    return { _type: 'typedef', name: name, docs: null, type: definition };
  }



TypeDefinition_ "Type Definition"
  = s:StructDefinition_ { return s; }
  / a:AliasDefinition_ { return a; }
  / c:CTypeDefinition_ { return c; }
  / d:ClassDefinition_ { return d; }
  / i:InterfaceDefinition_ { return i; }

////////////////////////////////////////////////////////////////////////////////

ClassDefinition_
  = "class" WS template:TemplatedStructure? fields:StructFieldList_
  {
    return { _type: 'class', fields: fields };
  }


TemplatedStructure "Templated structured data (class or struct or interface)"
  = "<" WS  args:FunctionDeclarationArgumentList  ">" WS ->{{ TEMPLATE with args }}

////////////////////////////////////////////////////////////////////////////////

InterfaceDefinition_
  = "interface" WS method_list:InterfaceMethodList_ { return { _type: 'interface', methods: method_list }; }

InterfaceMethodList_
  = "{" WS methods:InterfaceMethodDeclarationWithDocstring* "}" { return methods; }

InterfaceMethodDeclarationWithDocstring
  = doc:(d:DocString WS { return d; })? r:InterfaceMethodDeclaration { r.docs = doc; return r; }

InterfaceMethodDeclaration "Interface Method Declaration"
  = name:Identifier WS "=" WS func:FunctionDeclarationWithoutBody_ WS
  {
    return { name: name, func: func };
  }


////////////////////////////////////////////////////////////////////////////////
StructDefinition_
  = "struct" WS template:TemplatedStructure ? fields:StructFieldList_
  {
    return { _type: 'struct', fields: fields };
  }


StructFieldList_
  = "{" WS fields:FieldDeclarationWithDocstring* "}"
  {
    return fields;
  }

FieldDeclarationWithDocstring
  = doc:(d:DocString WS { return d; })? r:FieldDeclaration { r.docs = doc; return r; }

FieldDeclaration "Struct Field Declaration"
  = decl:VariableDeclaration_ SE { return decl; }

VariableDeclaration_ "Variable Declaration"
  = name:Identifier WS ':' WS  type:TypeName_
  {
    return { name: name, type: type  };
  }


////////////////////////////////////////////////////////////////////////////////

CTypeDefinition_ "A C type definition"
  = "C" WS c_name:StringLiteral
  {
    return { _type: 'ctype', raw: c_name };
  }

////////////////////////////////////////////////////////////////////////////////

AliasDefinition_ "Alias"
  = "alias" WS original:TypeName_
  {
    return { _type: 'alias', original: original  };
  }

TypeName_ "Type Name"
  = base:TypeNameBase
      extensions:( WS tap:TypeExtension { return tap;} )*

    {
      var out = { base: base, extension: null  };
      for(var i=0, len = extensions.length; i < len; ++i)
      {
        out = { base:out, extension: extensions[i] };
      }
      return out;
    }

TypeNameBase
  = name:Identifier { return name; }

TypeExtension "Array declaration part of types"
  =  "[" WS size:$DecimalIntegerLiteral WS "]"  { return { _type: 'array', size: size }; }
  /  op:"*" { return { _type: 'pointer' }; }
// TODO: Do we need references?
//  /  op:"&" { return { _type: 'array', size: size }; }



////////////////////////////////////////////////////////////////////////////////

Identifier "identifier"
  = text:IdentifierName
  {
    return { text: text.text, start: text.start, len: text.len };
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
  {
    return { _type: 'methodset', target: name, access: access, docs: null, methods: body };
  }

MethodListBody "Method List body"
  = "{" WS  decls:MethodDeclarationWithDocstring* "}" { return decls; }

MethodDeclarationWithDocstring
  = doc:(d:DocString WS { return d; })? r:MethodDeclaration { r.docs = doc; return r; }

MethodDeclaration "Method Declaration"
  = name:Identifier WS "=" WS func:FunctionDeclaration
  {
    return { name: name, func: func };
  }

MethodAccessor "Method acess controll"
  = "public"
  / "private"
// TODO: do we need protected? (is there inheritance?)
//  / "protected"


FunctionDeclaration "Function declaration"
  = args:FunctionArgList "->" WS returns:FunctionReturnType body:FunctionBody
  {
    return { args: args, returns: returns, body: body };
  }

FunctionDeclarationWithoutBody_ "Function declaration"
  = args:FunctionArgList "->" WS returns:FunctionReturnType
  {
    return { args: args, returns: returns };
  }

FunctionArgList "Type list for function parameters/return values"
  = "(" WS args:FunctionDeclarationArgumentList ")" WS { return args; }

FunctionReturnType
  = list: TypeList { return list; }

FunctionDeclarationArgumentList
  = first:FunctionArgumentFirst WS more:FunctionArgumentMore*
    { return [first].concat( more ); }
  / { return []; }

FunctionArgumentFirst
  = decl:VariableDeclaration_ { return decl; }


FunctionArgumentMore
  = ',' WS decl:VariableDeclaration_ WS { return decl; }


FunctionBody
  = "{" WS c:FunctionBodyContents  "}" WS { return c; }

////////////////////////////////////////////////////////////////////////////////

GlobalMethodDeclaration "Package global method declaration"
  = "func" WS name:Identifier WS "=" WS
    func:FunctionDeclaration
  {
    return {
      _type: 'methodset',
      target: null,
      access: "public",
      docs: null,
      methods: [ { name: name, func: func } ]
    };
  }


////////////////////////////////////////////////////////////////////////////////

TypeList "A list of types"
  = first:TypeName_ WS more:MoreTypes* { return [first].concat(more); }
  / { return []; }

MoreTypes = "," WS more:TypeName_ WS

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
