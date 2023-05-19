---
layout: post
title: 'Type Erasure in C++: The Polymorphic Type'
date: '2023-05-19 18:57:34'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure']
---


In the last post I described the type erasures provided by the STL. Most of the 
time they are not the best fitting options and also not the options people think 
about if you mention type erasures.[^1] The problem is not new and a lot of smart 
people work on type erasure implementations since decades. The implementation 
of [`std::any`][1] for example started with an article from Kevlin Henney back in 
2000.[^2] In this post I will describe the type erasure presented by Sean Parent 
in his famous talk from 2013: [Inheritance is The Base Class of Evil][2]

## Polymorphic Types

Sean Parent defines two importend points about polymorphism:
1. The requirements of a polymorphic type, by definition, comes from it's use
2. There are no polymorphic types, only *polymorphic use* of similar types

This points are very importend and taken up as base for a lot of type erasure 
implementations. So now that this is settled we go to the basics of his type 
erasure idea: move the polymorphic interface into a holder class. The type we 
want to erase is allocated in the holder class as a [PImpl][3] and the type 
erasure provides a unified interface to store and use the type in a type safe 
manner. This would look like this:

```cpp
#include <iostream>
#include <memory>
#include <vector>

struct dispatcher {
    void dispatch(const auto& msg) const noexcept {
        std::cout << "value: " << msg.value << '\n';
    }
};

class erasure {
   public:
    template <typename T>
    erasure(T data) : m_pimpl{new model_t<T>(std::move(data))} {}

    erasure(const erasure& other) : m_pimpl{other.m_pimpl->clone()} {}
    erasure& operator=(const erasure& other) {
        erasure(other).swap(*this);
        return *this;
    }

    erasure(erasure&&) noexcept = default;
    erasure& operator=(erasure&&) noexcept = default;

    void swap(erasure& other) noexcept {
        using std::swap;
        swap(m_pimpl, other.m_pimpl);
    }

    void dispatch(const dispatcher& sink) const { m_pimpl->dispatch(sink); }

   private:
    struct base_t {
        virtual ~base_t() = default;
        virtual base_t* clone() const = 0;

        virtual void dispatch(const dispatcher&) const = 0;
    };

    template <typename T>
    struct model_t : base_t {
        model_t(T data) : m_data{data} {}
        base_t* clone() const override { return new model_t(*this); }

        void dispatch(const dispatcher& sink) const override {
            sink.dispatch(m_data);
        }

        T m_data;
    };

    std::unique_ptr<base_t> m_pimpl{nullptr};
};

void dispatch(const erasure& msg, const dispatcher& sink) {
    msg.dispatch(sink);
}

struct int_message {
    int value = {};
};

struct float_message {
    float value = {};
};

int main() {
    std::vector<erasure> messages{int_message{.value = 42},
                                  float_message{.value = 3.14f}};

    dispatcher sink{};
    for (const auto& msg : messages) {
        dispatch(msg, sink);
    }
}
```

The `erasure` class makes the polymorphism to an implementation detail. The base 
class `base_t` defines the interface for the [PImpl][3] `m_pimpl`. The 
implemenation of the [PImpl][3] is the `model_t` template. This template 
resolves the call with his internal dispatch member method. 

This implementation allows polymorphism when it is needed and does not require 
the messages to inherit from any base class. This means the penalties of runtime 
polymorphism needs only to be paid when needed and do not have any type of 
additional coupling. Additional it gives the erasure a value semantic, which 
allows us to use it like every other type in the system.

Klaus Iglberger calls this pattern *Type Erasure Compound Design Pattern* and he 
describes it in great detail in his book *C++ Software Design*[^3]. This pattern 
combines external polymorphism, with the bridge and prototype design pattern.

## Extensions

If we want to extend the erasure we only need to touch the erasure class it 
self. We can add other operations into the `base_t` class and implement them in 
`model_t`. But what todo if a type we want to erase does not provide the member 
functions we would need? In this case we need to switch to free functions. If 
we change `model_t` to:

```cpp
    template <typename T>
    struct model_t : base_t {
        model_t(T data) : m_data{data} {}
        base_t* clone() const override { return new model_t(*this); }

        void dispatch(const dispatcher& sink) const override {
            ::dispatch(sink, m_data);
        }

        T m_data;
    };
```

We can use the [argument dependent lookup][4] to inject the neccessary 
functionality, which makes it highly flexible.

There is still one elephant in the room: *dynamic memory allocation*. This could 
create issues for realtime or embedded systems. We have implemented it so we can 
fix the problem in the implemenation directly and define the allocation like we 
want. Additionally we can create a small object optimization do prevent the use 
of the heap completly, if the type fits in the self defined boundaries.

## References

### Books

* Klaus Iglberger, C++ Software Design - Design Principles and Pattern for High-Quality Software

### Videos

* Sean Parent: GoingNative 2013 ["Inheritance Is The Base Class of Evil"][2]
* Sean Parent: CppNow 2013 ["Value Semantics and Concepts-based Polymorphism"](https://youtu.be/_BpMYeUFXv8)
  * "extended" version of *Base Class of Evil* (bad audio quality)
* Sean Parent: NDC {London} 2017 ["Better Code: Runtime Polymorphism"](https;//youtu.be/QGcVXgEVMJg)
  * updated version of *Value Semantics and Concepts-based Polymorphism* 
* Klaus Iglberger: CppCon 2021 ["Breaking Dependencies: Type Erasure - A Design Analysis"](https://youtu.be/4eeESJQk-mw)
* Klaus Iglberger: CppCon 2022 ["Breaking Dependencies: Type Erasure - The Implementation Details"](https://youtu.be/qn6OqefuH08)

## Footnotes

[^1]: Arthur O'Dwyer wrote a post about this and his understanding: [What is Type Erasure?](https://quuxplusone.github.io/blog/2019/03/18/what-is-type-erasure/)
[^2]: Kevlin Henney, C++ Report 12(7), July/August 2000 [Valued Conversion](https://web.archive.org/web/20120627084406/www.two-sdg.demon.co.uk/curbralan/papers/ValuedConversions.pdf)
[^3]: Klaus Iglberger, C++ Software Design - Design Principles and Pattern for High-Quality Software

[1]: https://en.cppreference.com/w/cpp/utility/any
[2]: https://youtu.be/bIhUE5uUFOA
[3]: https://en.cppreference.com/w/cpp/language/pimpl
[4]: https://en.cppreference.com/w/cpp/language/adl

