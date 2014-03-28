Mixins
======

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

