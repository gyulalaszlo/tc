Structs
=======

What is a struct?

Structs are the data in "data + methods != state + methods".

At first sight they look just like their C cousins: they contain fields
and can be passed by either pointer or by value. However they have some
constrains which makes them differ form what you are used to.

## Allowed field types

Since they are plain data, structs can only contain fields of the following
types:

### I. Basic types

1. integral types by value: U8, U16, U32, U64, I8, I16, I32, I64
2. floating point types by value: F32, F64
3. other structs by value (circular references by value are not
   allowed, as they would result in infinite-sized structs)
4. data blob types: Blob, Blob<T>

### II. Composite types

1. a List<T> if T is a Basic Type
2. a Map<T> if T is a Basic Type
3. a List<T> or Map<T> of any nesting depth where the base element type
   is a Basic Type.

So the values are what you would find for example in a JSON document.
By using only these types, we can be sure that the data of the struct
can be copied without any construction involved.

