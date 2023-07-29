---
layout: post
title: 'Type Erasure in C++: A Polymorphic Type'
date: '2023-05-28 10:43:31'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure']
---

> This is the second post in a series about type erasures:
> * [Part1][6]: The Basics
> * [Part2][7]: A Polymorphic Type
> * [Part3][9]: A Nonowning Type Erasure
{: .prompt-info }

In a [previews post][6], I described the type erasures provided by the STL. 
Most of the time, they are not the best suitable options or the options people 
consider if you mention type erasures.[^1] The problem is familiar, and many 
intelligent people have worked on type erasure implementations for decades. The 
implementation of [`std::any`][1], for example, started with an article from 
Kevlin Henney back in 2000.[^2] In this post, I will describe the type erasure 
presented by Sean Parent in his famous talk from 2013: 
[Inheritance is The Base Class of Evil][2]

## Polymorphic Types

Sean Parent defines two points about polymorphism:
1. The requirements of a polymorphic type, by definition, come from its use
2. There are no polymorphic types, only *polymorphic use* of similar types

These points are essential and taken up as a base for a lot of type erasure 
implementations. So now that we settled this, we go to the basics of his type 
erasure idea: move the polymorphic interface into a holder class. The type we 
want to erase is allocated in a holder class as a [PImpl][3], and the type 
erasure provides a unified interface to store and use the type in a type-safe 
manner. The implementation looks like this:

```cpp
#include <iostream>
#include <memory>

struct dispatcher {
    void dispatch(const auto& msg) const noexcept {
        std::cout << "value: " << msg.value << '\n';
    }
};

class erasure {
   public:
    template <typename T>
    erasure(T data) : m_pimpl{std::make_unique<model_t<T>>(std::move(data))} {}

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
        virtual std::unique_ptr<base_t> clone() const = 0;

        virtual void dispatch(const dispatcher&) const = 0;
    };

    template <typename T>
    struct model_t : base_t {
        model_t(T data) : m_data{data} {}
        std::unique_ptr<base_t> clone() const override { 
            return std::make_unique<model_t>(*this); 
        }

        void dispatch(const dispatcher& sink) const override {
            sink.dispatch(m_data);
        }

        T m_data;
    };

    std::unique_ptr<base_t> m_pimpl{nullptr};
};
```

The `erasure` class makes the polymorphism into an implementation detail. The 
base class `base_t` defines the interface for the [PImpl][3] `m_pimpl`. The 
implementation of the [PImpl][3] is the `model_t` template. This template 
resolves the call with his internal dispatch member method. 

The provided value semantic make's it also easy to use. The usage in our example 
can look like this:
```cpp
#include <vector>

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

This implementation allows polymorphism when needed and does not require the 
messages to inherit from a base class. With this runtime-penalties of 
polymorphism needs only to be paid when required and do not have any additional 
coupling. It also gives the erasure a value semantic, allowing us to use it 
like every other type in the system.

Klaus Iglberger calls this pattern *Type Erasure Compound Design Pattern*, and he 
describes it in great detail in his book *C++ Software Design*[^3]. This pattern 
combines external polymorphism with the bridge and prototype design pattern.

## Extensions

If we want to extend the erasure, we only need to touch the erasure class itself. 
We can add other operations into the `base_t` class and implement them in 
`model_t`. But what to do if a type we want to erase does not provide the 
necessary member functions? In this case, we need to switch to free functions. 
If we change `model_t` to:

```cpp
    template <typename T>
    struct model_t : base_t {
        model_t(T data) : m_data{data} {}
        std::unique_ptr<base_t> clone() const override { return std::make_unique<model_t>(*this); }

        void dispatch(const dispatcher& sink) const override {
            ::dispatch_to_sink(sink, m_data);
        }

        T m_data;
    };
```

We can use the [argument dependent lookup][4] to inject the necessary 
functionality, which makes it highly flexible.

One elephant is still in the room: *dynamic memory allocation*. Heap allocations 
could create issues for real-time or embedded systems. We have implemented it 
so we can fix the problem in the implementation directly and define the 
allocation like we want. Additionally, we can create a small object optimization 
to prevent the use of the heap completely if the type fits in the self-defined 
boundaries.

## Summary so far

We now know an additional way to create a type erasure beyond the options 
provided by the STL. We have seen an alternative that is type-safe without 
dependencies to [RTTI][5] and allows interface extension in a single place. If 
you want to try out this type erasure, you can do so in [compiler explorer][8].

## References

### Blogs

* [C++ Core Guidelines: Type Erasure](https://www.modernescpp.com/index.php/c-core-guidelines-type-erasure)
* [C++ Core Guidelines: Type Erasure with Templates](https://www.modernescpp.com/index.php/c-core-guidelines-type-erasure-with-templates)
* [C++ 'Type Erasure' Explained](https://davekilian.com/cpp-type-erasure.html)

### Books

* Klaus Iglberger: *C++ Software Design - Design Principles and Pattern for High-Quality Software* (2022)

### Videos

* Sean Parent: GoingNative 2013 ["Inheritance Is The Base Class of Evil"][2]
* Sean Parent: CppNow 2013 ["Value Semantics and Concepts-based Polymorphism"](https://youtu.be/_BpMYeUFXv8)
  * "extended" version of *Base Class of Evil* (bad audio quality)
* Sean Parent: NDC {London} 2017 ["Better Code: Runtime Polymorphism"](https://youtu.be/QGcVXgEVMJg)
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
[5]: https://en.wikipedia.org/wiki/Run-time_type_information
[6]: {% post_url 2023-05-21-type-erasure-the-basics%}
[7]: {% post_url 2023-05-28-type-erasure-polymorphic-type%}
[8]: https://godbolt.org/z/z5WbW9Eh3
[9]: {% post_url 2023-07-29-type-erasure-nonowning%}
