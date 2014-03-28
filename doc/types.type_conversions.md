Type conversions
================

There are some simple rules governing type conversions in tc.


Implicit type conversions
-------------------------

There are only a few cases of implicit type conversions, and these are
only for the built-in types:

- unsigned integer types (U8, U16, U32, U64) can be implicitly converted
  to any unsigned type T if T is wider then the base type (so U16 can be
  converted to U32, U64, but not U8)

- signed integer types (I8, I16, I32, I64) can be implicitly converted
  to any signed integer type T if T is wider then the base type (so I16 can be
  converted to I32, I64, but not I8)

- F32 can be implicitly converted to F64

If the target type is narrower then the source type, the conversion is
destructive, so tc requires you to cast it manually.


Casting
-------

Casting is really simple:

    // create a Foo instance
    foo := makeFoo()
    // ...
    // cast foo to type Bar
    bar := Bar(foo)


The allowed casts:

- converting between signed and unsigned integral types results in the
  equal C conversion happening

- conversion between floating point and integral types results in the
  equal C cast happening

- pointers can be converted to any other pointer type, so casting
  between pointer types is an unsafe and incredibly useful operation

- casting to a struct by value to another struct by default creates
  a blank output object and copies any matching fields (fields with the
  same name and a convertible basic type / structs )


Arithmetic casts
----------------

During arithmetic operations the following rules apply:

For binary operations where types differ ()

    '+', '-', '/', '*', '+=', '-=', ...

- as long as both operands are of the same basic type class (either
  signed int, unsigned int or float), the output is the widest of the
  operands

- if they are not of the same basic type class, manually casting one of
  the operands is required.

