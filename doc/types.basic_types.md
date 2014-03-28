Basic types
===========


Numeric types
-------------

Basic types are your bog standard primitive data types for storing
values. They are directly mapped to the underlying C types.

The built in datatypes for integer values:

    // 64, 32, 16 and 8 bit signed integer
    type i64 = C int64_t
    type i32 = C int32_t
    type i16 = C int16_t
    type i8 = C int8_t

    // 64, 32, 16 and 8 bit unsigned integer
    type u64 = C uint64_t
    type u32 = C uint32_t
    type u16 = C uint16_t
    type u8 = C uint8_t

The built in datatypes for floating point values:

    // 64 and 32 bit floating point
    type f64 = C double
    type f32 = C float


Pointer types
-------------

Pointers are different from C, as in their original C form, they serve
two purposes: they both are array (elements) and references to a remote
instance of a type.


In tc, these two roles are separated. Pointers are used as references to
foreign objects, while elements are used to return to a memory region
containing a continous stream of the base type.

### Pointers

Pointers are like C++ references, except they can be null. They have no
pointer arithmetic (a pointer points to a thing. you can either reassign
it to point to another object, to null, but you cannot add and substract
integral values to a pointer.

They are declared exactly like their C counterpart:

    // a pointer to a U32
    U32* uptr

    // a pointer to a structure
    List<U8>* strPtr

Except the pointer arithmetic part, they work exatly like you would expect
them in C++: you can call methods on them (but you use '.' instead of '->'
just like when accessing by value), access their fields if they are structs
and you can reassign both the pointer and the value it points to.

    meaningOfLife := 42
    // take the address of meaning
    meaningPtr := &meaningOfLife
    // do some math
    *meaningPtr = (*meaningPtr) * 4 + 1
    // meaningOfLife is now (4 * 42 + 1) = 169
    logger.Log( "meaning is now: #{ meaningOfLife }" )

Calling a method on a null target may or may not result in a runtime error,
just like in C.

### ListPointers

A listref is the other facet of C pointers: they are refernces to a memory region
filled with a continous stream of the base type. They can do all the things Pointers
can do, and pointer math can be applied to them.

They are declared:

  U32[] uListPtr


They are typically used to store the location of an allocated list, and pass it around.
Most of the time you will want to use the safer List<T> types (which contain a ListPointer
to the data and a length field)

  ParameterMetadata[] parameters := getParametersPtr()

  
