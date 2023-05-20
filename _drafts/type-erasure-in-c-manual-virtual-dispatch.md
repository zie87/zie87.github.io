---
layout: post
title: 'Type Erasure in C++: Manual Virtual Dispatch'
date: '2023-05-20 07:35:04'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure']
---

In this post I want to describe one of my favourite type erasures: a non owning 
type erasure, with manual virtual dispatch. This is quite a mouthful, but in 
general it is only some optimization over the polymorphic type which brings 
some additional advantages.

## The Pattern

This Pattern was described by Klaus Igleberger in his ["Breaking Dependencies"][2] 
talks. Lets start with the implementation and then explain what is going on:

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

This looks maybe a little bit more complicated than it is in the end. The idea 
is to store the address of the object as a `void*` (`m_object_ptr`), but also 
store how to convert this back in a type safe manner (`m_do`). The trick is in 
the construction: We make a templated constructor, which also creates a lambda 
for the conversion. A lambda without captures will give us a simple function 
pointer we can store. You can imagine it like the definition of a free function.
Additional the `dispatch_to` free functions allow us the manipulate the behavior 
via [argument dependent lookup][1]. 

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

This type erasure is my favourite, because it does not need any kind of 
expensive language feature. No allocation, no [RTTI][3], no exceptions and not 
even inheritance. But the best thing is it can easily be extended via template 
arguments. Lets take a look how we can support different kinds of dispatchers:

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

What we can do is create a tuple of function pointers to support all dispatcher. 
For this we need at first extract the function signatures. We can do this with 
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
the second trait (`dispatch_operations`) simply calls it for each of the 
variadic template arguments. Then we only need to replace the function ptr in 
the erasure with the tuple type:

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

This uses exactly the same trick like we have done with the single function 
version. The only difference is now that we create a lambda for each of the 
parameters and we need to fetch the right tuple entry in the `dispatch` member 
method. The usage would look like this[^2]:

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
pattern extremly useful for static dispatching. You simply define the types 
you want to dispatch create a specific erasure for the type sequence and you 
are ready to go.

## References

### Books

* Klaus Iglberger, C++ Software Design - Design Principles and Pattern for High-Quality Software

### Videos

* Klaus Iglberger: CppCon 2021 ["Breaking Dependencies: Type Erasure - A Design Analysis"](https://youtu.be/4eeESJQk-mw)
* Klaus Iglberger: CppCon 2022 ["Breaking Dependencies: Type Erasure - The Implementation Details"](https://youtu.be/qn6OqefuH08)
* Jason Turner: C++ Weekly Ep343 ["Digging Into Type Erasure"](https://youtu.be/iMzEUdacznQ)

## Footnotes

[^1]: You can find the example in compiler explorer: [https://godbolt.org/z/E434zGcbP](https://godbolt.org/z/E434zGcbP)
[^2]: You can find the example in compiler explorer: [https://godbolt.org/z/P59anjYch](https://godbolt.org/z/P59anjYch)

[1]: https://en.cppreference.com/w/cpp/language/adl
[2]: https://youtu.be/qn6OqefuH08
[3]: https://en.wikipedia.org/wiki/Run-time_type_information
