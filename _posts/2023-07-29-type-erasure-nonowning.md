---
layout: post
title: 'Type Erasure in C++: Nonowning Type Erasure'
date: '2023-07-29 10:44:30'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure']
---

> This is the third post in a series about type erasures:
> * [Part1][4]: The Basics
> * [Part2][5]: A Polymorphic Type
> * [Part3][6]: A Nonowning Type Erasure
{: .prompt-info }

In this post, I want to describe one of my favorite type erasures: a non owning 
type erasure with manual virtual dispatch. It sounds like quite a mouthful, but in 
general, it is only some optimization over the polymorphic type, which brings 
additional advantages.

## The Pattern

This pattern was described by Klaus Igleberger in his ["Breaking Dependencies"][2] 
talks. Let us start with the implementation and then explain what is going on:

```cpp
#include <type_traits>
#include <memory>

struct dispatcher;

class erasure {
   public:
    template <typename T>
        requires(!std::is_same_v<std::decay_t<T>, erasure>)
    erasure(const T& obj) noexcept
        : m_object_ptr{std::addressof(obj)}
        , m_do{[](const void* ptr, const dispatcher& sink) {
              dispatch_to(*static_cast<const T*>(ptr), sink); 
          }} 
    {}

    void dispatch(const dispatcher& sink) const { m_do(m_object_ptr, sink); }

   private:
    using operator_type = void(const void*, const dispatcher&);
    const void* m_object_ptr{nullptr};
    operator_type* m_do{nullptr};
};

void dispatch_to(const auto& msg, const dispatcher& sink) {
    sink.dispatch(msg);
}

void dispatch_to(const erasure& msg, const dispatcher& sink) {
    msg.dispatch(sink);
}
```

It may look more complicated than it is in the end. The idea 
is to store the object's address as a `void*` (`m_object_ptr`) but also 
to keep how to convert this back in a type-safe manner (`m_do`). The *trick* is in 
the construction: We make a templated constructor, which defines a lambda for the 
conversion. The standard guarantees that a lambda without captures will give us a 
function pointer we can store.

> The closure type for a **non-generic** lambda-expression with **no lambda-capture** 
whose constraints (if any) are satisfied has a **conversion function to pointer 
to function** with C++ language linkage having the same parameter and return 
types as the closure type’s function call operator. 
([C++ Standard Draft N4849](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2020/n4849.pdf) section *7.5.5.1.7 [expr.prim.lambda.closure]*)
{: .prompt-info }

The last *trick* is to use the `dispatch_to` free function, that allow us the 
manipulate the behavior via [argument dependent lookup][1]. 

Here you can see how this looks in action[^1]:

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
    int_message msg1{.value = 42};
    float_message msg2{.value = 3.14f};

    std::vector<erasure> messages({msg1}, {msg2});

    dispatcher sink{};
    for (const auto& msg : messages) {
        dispatch_to(msg, sink);
    }
}
```

## Extensions

This type erasure is my favorite because it does not need any kind of 
*"expensive"* language feature: No allocation, no [RTTI][3], no exceptions and not 
even inheritance. And the best thing is you can easily extend it via template arguments without any coupling. Let's take a look at how we can support 
different kinds of dispatchers:

```cpp
struct dispatcher1 {
    void dispatch(const auto& msg) const noexcept {
        std::cout << "[1] value: " << msg.value << '\n';
    }
};
struct dispatcher2 {
    void dispatch(const auto& msg) const noexcept {
        std::cout << "[2] value: " << msg.value << '\n';
    }
};
```

We can create a tuple of function pointers to support all dispatchers. 
For this, we need first to extract the function signatures. We can do this with 
simple helper traits:

```cpp
#include <tuple>
#include <type_traits>

namespace detail {

template <typename T>
struct dispatch_operation {
    using type = void(const void*, const std::decay_t<T>&);
};

template <typename... Ts>
struct dispatch_operations {
    using type = std::tuple<typename dispatch_operation<Ts>::type*...>;
};

}  // namespace detail
```

The trait `dispatch_operation` creates the signature for a single function and 
the second trait (`dispatch_operations`) calls it for each of the 
variadic template arguments. Then we only need to replace the function pointer in 
the erasure with the tuple type:

```cpp
using operation_types = typename detail::dispatch_operations<Ts...>::type;
operation_types m_calls{};
```
{: .nolineno}

Here we use the same trick as we have done with the single-function 
version. The only difference is that we create a lambda for each parameter:

```cpp
m_calls{[](const void* ptr, const std::decay_t<Ts>& msg) {
    dispatch_to(*static_cast<const T*>(ptr), msg);
  }...}
```
{: .nolineno}

And lastly, we need to fetch the right tuple entry in the `dispatch` member 
method:

```cpp
template <typename T>
void dispatch(const T& sink) const noexcept {
  std::get<typename detail::dispatch_operation<T>::type*>(m_calls)(m_ptr, sink);
}
```
{: .nolineno}

If we put all this together, it looks like this[^2]:

```cpp
#include <memory>
#include <tuple>
#include <type_traits>

template <typename... Ts>
class erasure {
   public:
    template <typename T>
        requires(!std::is_same_v<std::decay_t<T>, erasure>)
    erasure(const T& obj)
        : m_ptr{std::addressof(obj)},
          m_calls{[](const void* ptr, const std::decay_t<Ts>& msg) {
              dispatch_to(*static_cast<const T*>(ptr), msg);
          }...} {}

    template <typename T>
    void dispatch(const T& sink) const noexcept {
        std::get<typename detail::dispatch_operation<T>::type*>(m_calls)(m_ptr,
                                                                         sink);
    }

   private:
    using operation_types = typename detail::dispatch_operations<Ts...>::type;

    const void* m_ptr{nullptr};
    operation_types m_calls{};
};

void dispatch_to(const auto& msg, const auto& sink) { sink.dispatch(msg); }

template <typename... Ts>
void dispatch_to(const erasure<Ts...>& msg, const auto& sink) {
    msg.dispatch(sink);
}
```

The usage of this pattern is similar to his *"single-function"* version and would 
look like this[^2]:

```cpp
using erasure_type = erasure<dispatcher1, dispatcher2>;
std::vector<erasure_type> messages({msg1}, {msg2});

dispatcher1 sink1{};
dispatcher2 sink2{};
for (const auto& msg : messages) {
    dispatch_to(msg, sink1);
    dispatch_to(msg, sink2);
}
```

The option to create the signatures based on template arguments makes this 
pattern extremely useful for static dispatching. We define the types 
we want to dispatch, create a specific erasure for the type sequence, and are ready to go.

## Summary so far

A non owning type erasure provides an additional option for a type erasure. This 
erasure has a minimal cost and creates no other coupling in your system.
His properties allow the use as a drop-in replacement for interfaces 
where no ownership is needed. It is also very extendable because he uses free functions and has nearly no expectations about the stored type.

But it also has limitations. It is non-owning, so it is a create match for 
[dependency injection][7], but not for a context where owning would be the 
better choice. It also needs a fair amount of [boilerplate code][8] and the 
[argument dependent lookup][1] can create some *"surprises"* if it is not done 
properly.

## References

### Books

* Klaus Iglberger, C++ Software Design - Design Principles and Pattern for High-Quality Software

### Videos

* Klaus Iglberger: CppCon 2021 ["Breaking Dependencies: Type Erasure - A Design Analysis"](https://youtu.be/4eeESJQk-mw)
* Klaus Iglberger: CppCon 2022 ["Breaking Dependencies: Type Erasure - The Implementation Details"][2]
* Jason Turner: C++ Weekly Ep343 ["Digging Into Type Erasure"](https://youtu.be/iMzEUdacznQ)

## Footnotes

[^1]: You can find the example in compiler explorer: [https://godbolt.org/z/E434zGcbP](https://godbolt.org/z/E434zGcbP)
[^2]: You can find the example in compiler explorer: [https://godbolt.org/z/P59anjYch](https://godbolt.org/z/P59anjYch)

[1]: https://en.cppreference.com/w/cpp/language/adl
[2]: https://youtu.be/qn6OqefuH08
[3]: https://en.wikipedia.org/wiki/Run-time_type_information
[4]: {% post_url 2023-05-21-type-erasure-the-basics%}
[5]: {% post_url 2023-05-28-type-erasure-polymorphic-type%}
[6]: {% post_url 2023-07-29-type-erasure-nonowning%}
[7]: https://en.wikipedia.org/wiki/Dependency_injection
[8]: https://en.wikipedia.org/wiki/Boilerplate_code
