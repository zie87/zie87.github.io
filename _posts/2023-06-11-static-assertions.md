---
layout: post
title: 'Static Assertions with Classic C++: Leveraging Compile-Time Checks'
date: '2023-06-11 09:59:32'
categories: ['C++', 'Classic C++']
tags: ['c++', 'classic', 'history']
---

## Introduction

If we develop embedded software, we must check static attributes as soon as 
possible to ensure robust and reliable code. Such checks could be expectations 
about the size of a pointer or user-defined type. A valuable mechanism to 
perform such checks at compile-time are static assertions. 

Static Assertion
: A mechanism in C++,  also known as a compile-time assertion or compile-time 
check, that enables the verification of certain conditions at compile time. 

Static Assertions give us a lot of benefits for our code: 
1. **Compile-Time Error Detection**: We can check static expectations already during
    the compilation process. That avoids runtime checks or crashes and can ensure 
    correct behavior.
2. **Ensuring Type Safety**: Static Assertions can enforce type safety by verifying 
    assumptions about types, sizes, or relationships at compile time. So, for 
    example, we can check if a user-defined type has padding. 
3. **Portability and Cross-Platform Compatibility**: Compile-time checks are handy 
    when we want to port code to another platform. We can use them to ensure 
    specific assumptions about our platform, like the size of data types.
4. **Documentation and Readability**: Static Assertions can be a form of 
    self-documentation. We can use them to define our assumptions and contracts 
    or constraints in the source code, which improves the maintainability of 
    our code and prevents misuse. By including meaningful messages in our 
    assertions, we can also document the reason for our constrain. Additionally, 
    we can improve the compiler output for template code by using static 
    assertions to check type constraints beforehand.

[C++11][4] introduces the keyword [`static_assert`][3] to trigger a compiler 
error if the condition check fails. To provide similar functionality for 
older C++ versions, we must enforce a compile error based on a condition 
evaluated at compile time. There are different ways to implement such checks. 
Let's start with an implementation in C:

## Static Assertions with C

Since [C11][6] C also includes static assertion in the language with the 
keyword [`_Static_assert`][7][^1]. Before this inclusion, you could implement a 
compile-time assertion with macros like this[^2]:

```cpp
#define STATIC_ASSERT(cond, msg) typedef char msg[(cond) ? 0 : -1]

STATIC_ASSERT(sizeof(int) == 4, int_size_check);
```

This implementation defines a `STATIC_ASSERT` macro, which takes a condition (`cond`) 
and an indicator for the error message (`msg`). Inside the macro, a `typedef` is 
created. This `typedef` declares an array with `msg` as its name and a size
of `0` or `-1`, depending on the condition `cond`. If `cond` is evaluated to 
true, the array will get a valid size of `0`. However, if the condition is false, 
the array receives a negative length, which is invalid and will generate a 
compilation error like this:

```
<source>:1:58: error: size '-1' of array 'long_size_check' is negative
    1 | #define STATIC_ASSERT(cond, msg) typedef char msg[(cond) ? 0 : -1]
```

The array name in the error message provides you the information about the 
kind of error. In this case, the error is `long_size_check`, which tells us 
that the expected size for `long` does not match. The idea to utilize the array 
size for this kind of check was already described in 1997 in the article 
[*Compile-Time Assertions in C++*][5] by Kevin S. Van Horn.  

## Static Assertions with C++

In C++, we can utilize [partial template spezialisation][9] to archive the same 
result. The following listing shows a possible implementation[^3]:

```cpp
template <bool CONDITION>
struct static_assertion;

template <>
struct static_assertion<true> {
    static_assertion() {}
    
    template<typename T>
    static_assertion(T) {}
};
```

The idea is simple: we declare our `static_assertion` in dependency of a 
boolean template parameter and then specialize it to allow the compiling if the 
condition is true. To use it, we need to instantiate an object of `static_assertion`:

```cpp
const static_assertion<sizeof(int) == 4> ASSERT1("invalid size of int");
```

This object instantiation is quite lengthy but also provides a useful error 
message like:

```cpp
<source>:13:50: error: variable 'const static_assertion<false> ASSERT2' has initializer but incomplete type
   13 | const static_assertion<sizeof(long) == 4> ASSERT2("invalid size of long");
```

However, it is possible to wrap the functionality into a macro to make it easier. 
[Loki][10], for example, provides an implementation like this:

```cpp
#define CONCAT( X, Y ) CONCAT_SUB( X, Y )
#define CONCAT_SUB( X, Y ) X##Y

#define STATIC_ASSERT(expr, msg) \
  enum { CONCAT(ERROR_##msg, __LINE__) = sizeof(static_assertion<expr != 0 >) }

STATIC_ASSERT((sizeof(int) == 4), invalid_size_of_int);
```

## Summary

Static Assertions are a powerful tool to verify conditions and assumptions at 
compile time. Despite lacking the `static_assert` keyword, we can leverage 
Static Assertions in *Classic C++* using templates or macros. Verifying conditions 
at compile time improves code reliability, catches errors early, and documents 
essential constraints. It helps us avoid runtime errors and port our code to 
other platforms or verify the code if we use other compilers.

## References

### Articles

* Kevin S. Van Horn: C/C++ Users Journal Volume 15 Issue 10 [*Compile-Time Assertions in C++*][5] (1997)

### Books

* Andrei Alexandrescu: *Modern C++ Design - Generic Programming and Design Pattern Applied* (2000)
* Davide Di Gennaro: *Advanced Metaprogramming in Classic C++* (2015)

### Libraries

* [Loki][10] provides this functionality as `CompileTimeError`
* [Boost.StaticAssert][11] provides the macros `BOOST_STATIC_ASSERT` and `BOOST_STATIC_ASSERT_MSG`

## Footnotes

[^1]: with [C23][8] `_Static_assert` will be renamed to [`static_assert`](https://en.cppreference.com/w/c/language/_Static_assert)
[^2]: you can find the implementation in [compiler explorer](https://godbolt.org/z/vancxEzbr)
[^3]: you can find the implementation in [compiler explorer](https://godbolt.org/z/s3nj14sre)

[1]: https://en.wikipedia.org/wiki/C%2B%2B03
[2]: https://gcc.gnu.org/gcc-4.8/
[3]: https://en.cppreference.com/w/cpp/language/static_assert
[4]: https://en.wikipedia.org/wiki/C%2B%2B11
[5]: https://web.archive.org/web/20000816131057/http://www.xmission.com/~ksvhsoft/ctassert/ctassert.html
[6]: https://en.wikipedia.org/wiki/C11_(C_standard_revision)
[7]: https://en.cppreference.com/w/c/language/_Static_assert
[8]: https://en.wikipedia.org/wiki/C23_(C_standard_revision)
[9]: https://en.cppreference.com/w/cpp/language/partial_specialization
[10]: https://loki-lib.sourceforge.net/
[11]: https://www.boost.org/doc/libs/1_82_0/doc/html/boost_staticassert.html
