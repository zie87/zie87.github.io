---
layout: post
title: 'Type Erasure in C++: The Basics'
date: '2023-05-21 19:33:37'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure']
---

> This is the first post in a series about type erasures:
> * [Part1][6]: The Basics
> * [Part2][7]: A Polymorphic Type
{: .prompt-info}

We needed to implement a dynamic message dispatching at work some weeks ago. 
We had different kinds of messages, which we needed to store in a queue and 
dispatch to systems. To store the messages, a type erasure was required. But 
what is a type erasure?

Type Erasure 
: A technique to enable the use of various concrete types through a single generic interface.[^1]

## Inheritance

The most obvious type erasure to use for this would be inheritance:

```cpp
#include <iostream>
#include <vector>

struct dispatcher {
    void dispatch(const auto& msg) const noexcept {
        std::cout << "value: " << msg.value << '\n';
    }
};

struct base_message {
    virtual ~base_message() = default;
    virtual void dispatch(const dispatcher& sink) const = 0;
};

struct int_message : base_message {
    int_message(int val) noexcept : value(val) {}
    void dispatch(const dispatcher& sink) const override {
        sink.dispatch(*this);
    }

    int value = {};
};

struct float_message : base_message {
    float_message(float val) noexcept : value(val) {}
    void dispatch(const dispatcher& sink) const override {
        sink.dispatch(*this);
    }

    float value = {};
};

int main() {
    int_message msg1{42};
    float_message msg2{3.14f};

    std::vector<const base_message*> messages{&msg1, &msg2};

    dispatcher sink{};
    for (const auto& msg : messages) {
        msg->dispatch(sink);
    }
}
```

For this approach, we only needed to define an interface (`base_message`) used 
by all messages. The interface allows to store all messages in the same container.
But this is also the biggest drawback of this solution: everything needs to inherit 
from the base class: this means we need to wrap unrelated classes if we want to 
store them. It also means everything is strongly coupled to the interface. As 
soon as the base class changes, all hell breaks loose.

## Any Type

The STL provides, since C++17, a container type for a single value, which can be 
used: [`std::any`][1]. The idea behind this type is not new and was also available 
for *classic C++* with [`boost::any`][1] since [Boost][3] version *1.23.0*. This type 
provides storage for a type internally and hides the type information. To use the 
internal type you need to cast it back. This cast will only succeed if the underlying 
type matches the cast type. In our example the usage would look like this:

```cpp
#include <any>
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
    std::vector<std::any> messages{int_message{.value = 42},
                                   float_message{.value = 3.14f}};

    dispatcher sink{};
    for (const auto& msg : messages) {
        if (msg.type() == typeid(int_message)) {
            sink.dispatch(std::any_cast<int_message>(msg));
            continue;
        }
        if (msg.type() == typeid(float_message)) {
            sink.dispatch(std::any_cast<float_message>(msg));
            continue;
        }
    }
}
```

Using [`std::any`][1], we can now store each type we can imagine. No base class is 
needed. But now we have a higher price to pay: with this, we rely on the heaviest 
mechanisms of C++. We need dynamic allocation of memory to create an any objects, 
without the possibility of injecting an allocator[^2], it can throw a 
`std::bad_any_cast` exception on the casts, and we need C++ [RTTI][4] for the 
`type()` member function and for `typeid`. Furthermore, nobody can help us if we 
forget to add a type check inside the for-loop.

We can avoid [RTTI][4] and exceptions, if we change to loop to a pointer cast:
```cpp
    for (const auto& msg : messages) {
        if (auto* ptr = std::any_cast<int_message>(&msg); ptr != nullptr ) {
            sink.dispatch(*ptr);
            continue;
        }
        if (auto* ptr = std::any_cast<float_message>(&msg); ptr != nullptr ) {
            sink.dispatch(*ptr);
            continue;
        }
    }
``` 

This will not throw anymore, but now we need to handle `nullptr` and still can 
forget to handle a type. We can fix this issue by combining the type with the 
dispatch function. The STL also provides an erasure type for this: [`std::function`][5]

## Function Wrapper

With [`std::function`][5], we can accept everything which behaves like a 
function. This means we can use it if we change the container to store the operation 
rather than the type:

```cpp
#include <functional>
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
    using function_type = std::function<void(const dispatcher&)>;

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

Now we store the operation so it is impossible to forget to handle a type. 
We still do not need any base class and can hold whatever we want if it fits 
the signature `void(const dispatcher&)`. We can rely on the small object 
optimization of [`std::function`][5] if we do not need to capture values inside 
the function objects. This approach works well as we only need one operation, 
and our objects are small. But what happens if this is not the case? When we 
have multiple operations on the same objects, we need various containers or 
combine multiple [`std::function`][5] into a type we can store. If our objects 
are getting bigger, we also need to care about the storage of these objects, 
especially if they need to be shared between different operations.

## Summary so far

We have looked at the *out of the box* options C++ and the STL provides. 
Every option comes with advantages and disadvantages. None of the 
alternatives is satisfying. In the next post, we will look at other 
options, combining templates with different techniques to provide more 
case-specific solutions.

## References

### Blogs

* [C++ Core Guidelines: Type Erasure](https://www.modernescpp.com/index.php/c-core-guidelines-type-erasure)

### Videos

* Jason Turner: C++ Weekly Ep343 ["Digging Into Type Erasure"](https://youtu.be/iMzEUdacznQ)

## Footnotes

[^1]: This definition is based on Rainer Grimms article [C++ Core Guidelines: Type Erasure](https://www.modernescpp.com/index.php/c-core-guidelines-type-erasure)
[^2]: Most any implementations provide small object optimization, which could avoid the allocation.

[1]: https://en.cppreference.com/w/cpp/utility/any
[2]: https://www.boost.org/doc/libs/1_82_0/doc/html/any.html
[3]: https://www.boost.org
[4]: https://en.wikipedia.org/wiki/Run-time_type_information
[5]: https://en.cppreference.com/w/cpp/utility/functional/function
[6]: {% post_url 2023-05-21-type-erasure-the-basics%}
[7]: {% post_url 2023-05-28-type-erasure-polymorphic-type%}
