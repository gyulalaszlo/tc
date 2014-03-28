TC
==

A Work in progress experimental language where:

> The Same Thing does The Same Thing and thats A Good Thing


- __no polymorphism__
- __no subclassing__
- __allow only the minimal amount of implicit casts__ necessary for convinient math
- __pointers and arrays should be different things depending on their meaning__
- __no passing of anything using a constructor by value__
  ( Who owns it? How do you copy it? too many implementation-specific questions,
  where the answer depends on the specific context of the implementation)
- functions __can be refactored__ between targets __via simple copy and paste__

> Everything has an owner. You allocated it, you own it.

- focuses on low-level tasks that require allocation management

> Everything has an owner. You allocated it, you own it.

- has static typing

- yet provides high-level idioms like blocks

- (hopefully) can compile to production quality C or C++ code


See the doc directory for more information
