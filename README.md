# TC

A Work in progress experimental language that:
- focuses on low-level tasks that require allocation management
- yet provides high-level idioms like blocks
- (hopefully) can compile to production quality C or C++ code

# Structure of a tc package

While tc isnt designed for writing complete programs, a package doing the familiar "Hello World" would in look something like this:

    package hello;

    imports = {
      "logger"
    }

    SayHello = fn( logger.Log& log ) {
      log.Info( "Hello World!" );
    }

## The first line

    package hello;

tells that you are writing the stuff for the package (and not the tests for example). The package name is the name of the directory the package resides in (aka. the last path part of the import string).


## The imports

    imports = {
      "logger"
    }

Once upon a time, C++ used to #include files. And managing them became a burdensome job the larger the a project grew.

The classic problem with C (and C++) is that all declarations in a program are declared in the same namespace, and without any controll over remote packages, naming things just became too important.

Tc tries to solve (parts of) this issue by packing types and methods into "packages", and using imports to resolve references between packages. By importing the package "logger" all types and methods exported by logger are available through the "logger." symbol.

## Saying something

    SayHello = fn( logger.Log& log ) {
      log.Info( "Hello World!" );
    }

Here we define a simple function called "SayHello" that takes a
reference named "log" of type "Log" from the package "logger".

The next line simply calls the "Info" method of "log" with our desired
output.



# Basic types

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



# Structs

# Classes

# Mixins

## What is a Mixin?

Mixins are the inverse concept of interfaces: they aim to provide common
functionality for structs of many different types.

    // A Person requires a name and an age
    type Person = mixin<AgeT:typename> {
      name: CStr
      age:  AgeT
    }

Later we can define methods on this mixin

    public Person = {
      Greet = ()-> { @sayWithName("hello"); }
      IsAllowedToDrink = ()-> bool { return @age > (18 as AgeT); }
      say = (what:CStr)-> { console.Log( "%s %s", what, @name ); }
    }

## Extending Structs with Mixins

Now that we have our Person mixin ready, we need something to include it
into.

    type Guest = {
      name: CStr
      age: U32
      // more fields omitted
    }

To use this mixin, we need to use the "extend" keyword

    extend <struct> with <mixin1>, [<mixin2>, <mixin3>]

Now calling extend will enable the calls on Guest instances FOR THE
CURRENT FILE

    extend Guest with Person<U32>

Since TC tries to be a good citizen, it tires to adapt to the needs of
the situations with templates as seen on the following example.

    type List = struct<T:typename> {
      data: T*
      length: U32
    }

    type PointerList = mixin<T:typename, LenT:typename> {
      data: T**
      length: LenT
    }

    extend List with PointerList

Here TC understands that what you really want to say is:

    // for each 'T' I you use 'List<T*>' for
    extend List<T*> with PointerList<T,U32> 


