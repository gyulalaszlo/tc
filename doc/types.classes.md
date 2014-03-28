Classes
=======

## What is a class?

A class is the "state" in "data + methods != state + methods".

Just like structs are designed to store and pass data through
components, classes are the components that operate on and trasform the
data. They generally encapsulate a single aspect of data processing,
where the transformation requires state, or longer-living "managers"
that coordinate and communicate between lower level components.

The key difference between structs and classes is that only the class
itself has access to its fields (its state is hidden from the outside),
and it can only be passed by reference (so the data itself is never
copied).

Classes can have any types as fields.

## Construction

Another key diffenece between classes and structs is that classes arent
created by value, but rather by invoking their construction:

    """ A histogram for character streams. """
    type U8Histogram = class {
      values: U32[256]
      list: List<U32>
    }

    public U8Histogram = {
      """ Create a blank histogram. """
      Constructor = ()-> { @initialize() }

      """ Create a histogram by using the passed values as base. """
      Constructor = ( @values: U32[256] )-> { @initialize() }


      """ Add a list of characters to the histogram. """
      Add = (characters: List<U8>) {
        // iterate over each character using List.each
        characters.each( | c, _ )-> {
          // increment the count of the character
          @values[c] += 1
        }
      }

      """ Get a direct reference to the histogram data.  """
      Histogram = ()-> List<U32> {
        return @list
      }

      """ Copy the current state of the histogram. """
      NormalizedCopy = (alloc:Allocator*)-> List<U32> {
        // using the sum function
        sum := @list.sum()
        // and map using the allocator
        return @list.map<F64>( alloc | count, _ )-> {
          return F64(count) / F64(sum)
        }
      }

    }

    private U8Histogram = {
      initialize = ()->{
       @list = List<U32>.fromStaticArray(values)
      }
    }

    //...
    swapper := U32Swapper( )

