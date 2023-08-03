---
layout: post
title: 'Type Erasure in C++: A callable reference'
date: '2023-08-03 12:47:00'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure', 'functional', 'function_ref']
---

I regularly need to pass functions or callables around in my daily work. 
If you want to implement a work queue or if you're going to implement an observer 
you will need to pass and store callable objects.

> This is the fourth post in a series about type erasures:
> * [Part 1: The Basics][2]
> * [Part 2: A Polymorphic Type][3]
> * [Part 3: A Nonowning Type Erasure][4]
> * [Part 4: A callable reference][5]
{: .prompt-info }

## What do we have?

In C++, you have some options to do this out of the box: function pointers, 
[`std::function`][8], [`std::move_only_function`][9][^3] or templates. All this 
options come with their advantages and drawbacks.[^1] For me, as an embedded C++ 
developer following points or important:
1. easy to use and works with most callable objects
2. small overhead (small object size, no allocations, no exceptions)
3. no bloat and good to optimize

None of the provided options checks all criteria: 
* templates are not so easy to use and can potentially bloat the system[^2] 
* function pointer can not handle most callable objects
* [`std::function`][8] and [`std::move_only_function`][9] have a larger 
  object size to allow small buffer optimization or need dynamic memory and are 
  not easy to optimize by the compiler.

But gladly, there is another option: ***`function_ref`***.

## The Pattern

A `function_ref` (sometimes called `function_view`) is a lightweight non-owning 
generic callable object with reference semantics. This description makes it already 
similar to the [non-ownwing type erasure][4] described in the previous type erasure 
post. And the main idea is nearly identical: store the callable type erased and 
hold a function pointer to a lambda, which handles a type-safe cast based on a generic constructor.

The C++ standard does not yet provide a `function_ref` implementation, but it 
is already [proposed][1]. Lucky for us, a simple version is easy to 
implement. 

At first, we need to enforce a function signature as a template 
parameter. We do this via [partial template specialization][10]. We need o define the template prototype:

```cpp
template <typename>
class function_ref;
```
{: .nolineno}

The prototype allows us to enforce a signature with a template specialization:

```cpp
template <typename RETURN_T, typename... ARG_Ts>
class function_ref<RETURN_T(ARG_Ts...)> {
  /* ... */
};
```
{: .nolineno}

The next step is to define our member parameters. We need a `void*` to store 
the address for our callable object: `void* m_callable{nullptr};`{: .cpp}. We also need 
a pointer to a function that will receive our `m_callable` together with all 
function parameters:

```cpp
using function_type = RETURN_T(void*, ARG_Ts...);
function_type* m_erased_fn{nullptr};
```
{: .nolineno}

Now we need to define a generic constructor which initializes our member variables. 
`m_callable` will store the address of the provided callable, and `m_erased_fn` 
needs to point at a function that will cast our callable back in his original 
type and then calls it with all parameters:
```cpp
template <typename CALLABLE_T>
    requires(!std::is_same_v<std::decay_t<CALLABLE_T>, function_ref>)
function_ref(CALLABLE_T&& callable) noexcept
    : m_callable{std::addressof(callable)}
    , m_erased_fn{[](void* ptr, ARG_Ts... args) -> RETURN_T {
          return (*static_cast<std::add_pointer_t<CALLABLE_T>>(ptr))(
              std::forward<ARG_Ts>(args)...);
      }} 
{}
```
{: .nolineno}

The last step is to define our call operator. This operator only needs to call 
`m_erased_fn` with our stored callable (`m_callable`) and all necessary 
parameters:

```cpp    
RETURN_T operator()(ARG_Ts... args) const {
  return m_erased_fn(m_callable, std::forward<ARG_Ts>(args)...);
}
```
{: .nolineno}

If we put all this together, it looks like this[^5]:

```cpp
#include <memory>
#include <type_traits>

template <typename>
class function_ref;

template <typename RETURN_T, typename... ARG_Ts>
class function_ref<RETURN_T(ARG_Ts...)> {
   public:
    template <typename CALLABLE_T>
        requires(!std::is_same_v<std::decay_t<CALLABLE_T>, function_ref>)
    function_ref(CALLABLE_T&& callable) noexcept
        : m_callable{std::addressof(callable)}
        , m_erased_fn{[](void* ptr, ARG_Ts... args) -> RETURN_T {
              return (*static_cast<std::add_pointer_t<CALLABLE_T>>(ptr))(
                  std::forward<ARG_Ts>(args)...);
          }} 
    {}

    RETURN_T operator()(ARG_Ts... args) const {
        return m_erased_fn(m_callable, std::forward<ARG_Ts>(args)...);
    }

   private:
    using function_type = RETURN_T(void*, ARG_Ts...);
    void* m_callable{nullptr};
    function_type* m_erased_fn{nullptr};
};
```

> The provided implementation is only an example and has some serious flaws and 
> is only to illustrate the idea. If you want use it you should stick to an 
> already existing implementation like [zhihaoy/nontype_functional@p0792r13.][17]
> or adapt the implementation. This blog post gives a good overview what you 
> should consider: [Implementing `function_view` is harder than you might think][16]
{: .prompt-warning }

We can use it similar to the [`std::function`][8] implementation of the first type 
erasure [post][2][^4]:

```cpp
#include <iostream>
#include <vector>

struct dispatcher {
    void dispatch(const auto& msg) const noexcept {
        std::cout << "value: " << msg.value << '\n';
    }
};

struct int_message {
    int value = {};
};

struct float_message {
    float value = {};
};

int main() {
    using function_type = function_ref<void(const dispatcher&)>;

    std::vector<function_type> messages{[](const dispatcher& sink) { 
                                            int_message msg{.value = 42}; 
                                            sink.dispatch(msg);
                                        },
                                        [](const dispatcher& sink) { 
                                            float_message msg{.value = 3.14f}; 
                                            sink.dispatch(msg);
                                        },};

    dispatcher sink{};
    for (const auto& msg : messages) {
        msg(sink);
    }
}
```

In this code, we create a vector of our `function_ref` type, which stores the 
addresses of non-generic lambdas without capture and use the call 
operator for each of them inside the for loop.

## Summary so far

A `function_ref` object provides a lightweight and efficient way to work with 
callable objects in C++. It is a non-owning alternative to [`std::function`][8], 
which completely avoids unnecessary memory allocations, and still containing a 
small object size. These properties allow a significant performance improvement 
compared to [`std::function`][8][^6] and make it a perfect tool in the 
toolbox for embedded development.

## References

### Blogs

* [Vittorio Romeo][6]: [passing functions to functions][12]
* [Foonathan][7]: [Implementing `function_view` is harder than you might think][16]

### Paper 

* P0792: [`function_ref: a type-erased callable reference`][1]

### Videos

* Vittorio Romeo: Meeting C++ 2017 [Lightning Talk: `function_ref`](https://youtu.be/6EQRoqELeWc)
* Vittorio Romeo: CppNow 2019 [Higher-order functions and `function_ref`](https://youtu.be/5V74RPUEu5s)

### Code

* [zhihaoy/nontype_functional@p0792r13][17] complete implementation of `function_ref`
* [`llvm::function_ref`][11] implementation used by to LLVM Project
* [`tl::function_ref`](https://github.com/TartanLlama/function_ref) implementation by *Tartan Llama*

## Footnotes

[^1]: The proposal [P0792][1] provides a good overview over the advantages and disadvantages.
[^2]: Jason Turner wrote an article about this: [template code bloat](https://articles.emptycrate.com/2008/05/06/nobody_understands_c_part_5_template_code_bloat.html)
[^3]: `std::move_only_function` will be part of [C++23](https://en.cppreference.com/w/cpp/23) and was proposed in [P0288](wg21.link/p0288r9)
[^4]: You can find the example in compiler explorer: [https://godbolt.org/z/evorMPo58](https://godbolt.org/z/evorMPo58) 
[^5]: This implementation is a slightly simplified version of [`llvm::function_ref`][11]
[^6]: You can see a benchmark in this blog post: [passing functions to functions][12]


[1]: https://wg21.link/p0792r14
[2]: {% post_url 2023-05-21-type-erasure-the-basics%}
[3]: {% post_url 2023-05-28-type-erasure-polymorphic-type%}
[4]: {% post_url 2023-07-29-type-erasure-nonowning%}
[5]: {% post_url 2023-08-03-type-erasure-function-ref%}
[6]: https://vittorioromeo.info/index.html 
[7]: https://www.foonathan.net/
[8]: https://en.cppreference.com/w/cpp/utility/functional/function
[9]: https://en.cppreference.com/w/cpp/utility/functional/move_only_function
[10]: http://en.cppreference.com/w/cpp/language/partial_specialization
[11]: https://github.com/llvm/llvm-project/blob/llvmorg-16.0.6/llvm/include/llvm/ADT/STLFunctionalExtras.h
[12]: https://vittorioromeo.info/index/blog/passing_functions_to_functions.html
[16]: https://www.foonathan.net/2017/01/function-ref-implementation/
[17]: https://github.com/zhihaoy/nontype_functional/blob/p0792r13/include/std23/function_ref.h
