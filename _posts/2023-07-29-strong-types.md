---
layout: post
title: 'Enhancing Type Safety with Strong Types'
date: '2023-07-29 08:32:29'
categories: ['C++']
tags: ['c++']
---

## Introduction

Have you ever asked yourself which unit a function return type has? Does `sleep` 
use milliseconds or microseconds? Have you ever mixed up the order of your function 
parameters? If so, **Strong Types** are here to help you prevent this issue from happening again.

Strong Typing is a technique that allows one to differentiate between semantically 
distinct values of the same underlying type. The idea is to wrap the underlying 
type to prevent accidental mixing and ensure structured conversion between types 
(e.g., conversion between seconds and hours). The use of strong types provides 
some benefits:

1. **Self-Documenting Code:** Strong types make code more expressive by reflecting 
the intention of the domain directly in the type names. They make your APIs 
clearer and more readable, which makes it easier for other developers to understand 
the codebase.
2. **Improved Type Safety:** Distinct types for different entities prevent unintended 
conversion. Furthermore, type-related bugs can be detected at compile time, reducing the possibility of hard-to-spot run-time bugs and enhancing code 
reliability.
3. **Easier Maintenance:** Strong types can make refactoring or extending the 
code base easier. If your system needs to handle a new kind of measurement unit or in 
some parts of the code, you need another scaling (e.g., nano vs. milli), the type 
system can handle the integration and conversion for you.

## Basic Implementation

The easiest way to implement strong types is via **tag types**. A **tag type** is a 
type definition (mostly an empty `struct`), which provides a tag that allows 
the type system to distinguish the same type in different ways. The idea is to 
combine the value type with the **tag type** to create a new unique type. We can use 
a `template` for this:

```cpp
template <typename VALUE_T, typename TAG_T>
class strong_type {
   public:
    using value_type = VALUE_T;
    explicit constexpr strong_type(const value_type& value) : m_value(value) {}

    friend inline constexpr value_type underlying_value(const strong_type& value) {
        return value.m_value;
    }

   private:
    value_type m_value{};
};
```

The `strong_type` class template now provides a generic interface for strong 
types. The free friend function `underlying_value` allows fetching the underlying 
value if needed. If you want to use `strong_type`, you only need to define a 
unique tag and create an alias for readablity[^2]:

```cpp
#include <cstddef>

namespace detail {
struct user_id_tag {};
struct product_id_tag {};
}  // namespace detail

using user_id = strong_type<std::size_t, detail::user_id_tag>;
using product_id = strong_type<std::size_t, detail::product_id_tag>;
```

The tag makes the types unique and allows the type system to distinguish between 
them.

## Conversion

The proposed implementation will be enough to avoid issues like mixing up 
parameters and allows better reasoning about the code base. In the past, I worked 
on a system where parts of the system provided data in fractions of nautical miles, 
and other components provided the data in meters or fractions of meters. Strong types 
will help to avoid mixing them up, but they can do more for you. Strong types allow you 
to implement a type conversion that will handle the translation between such 
types at compile time.

### Define the Ratio

The [`std::chrono`][1] already provides a strong type which allows something like 
this: [`std::duration`][2]. The [`std::duration`][2] class declaration looks like this:

```cpp
template<typename VALUE_T, typename PERIOD_T = std::ratio<1>> 
class duration;
```
This implementation combines the value type of duration with his 
(compile-time) rational fraction. We only need to add a template parameter for 
the rational fraction if we want to provide the same functionality 
for our generic strong type. The implementation would look like this:

```cpp
#include <ratio>

template <typename VALUE_T, typename TAG_T, typename RATIO_T = std::ratio<1>>
class strong_type;
```

The default type for `RATIO_T` allows us to use the type in the same way like 
before. If we want to define types that should enable a conversion, we need to 
use the same tag with the matching ratio[^3]:

```cpp
namespace detail {
struct distance_tag {};
};  // namespace detail

using meter = strong_type<double, detail::distance_tag, std::ratio<1>>;
using centimeter = strong_type<double, detail::distance_tag, std::centi>;
using millimeter = strong_type<double, detail::distance_tag, std::milli>;
using nautical_mile = strong_type<double, detail::distance_tag, std::ratio<1'852,1>>;
```

If you want to improve the readability of these aliases, you can define a similar 
type for the distance like the STL has done for [`std::duration`][2]:

```cpp
template<typename VALUE_T, typename RATIO_T>
using distance = strong_type<VALUE_T, detail::distance_tag, RATIO_T>;

using meter = distance<double, std::ratio<1>>;
using centimeter = distance<double, std::centi>;
using millimeter = distance<double, std::milli>;
using nautical_mile = distance<double, std::ratio<1'852,1>>;
```

### Type Casting

Now we have defined the ratio between similar types. The next step would be to 
convert between the types. The STL has defined a dedicated cast for converting 
durations: [`std::duration_cast`][4]. We can provide a similar cast 
for our distance unit. To do so, we need first some helpers:

```cpp
namespace detail {
template <typename>
struct ratio;

template <typename VALUE_T, typename TAG_T, typename RATIO_T>
struct ratio<strong_type<VALUE_T, TAG_T, RATIO_T>> {
    using type = RATIO_T;
};

template <typename T>
using ratio_t = typename ratio<T>::type;

template <typename>
struct value;

template <typename VALUE_T, typename TAG_T, typename RATIO_T>
struct value<strong_type<VALUE_T, TAG_T, RATIO_T>> {
    using type = VALUE_T;
};

template <typename T>
using value_t = typename value<T>::type;
}  // namespace detail
```

These helpers will allow us to extract the ratio and value types for our 
distances. To define the conversion, we need first to *"unify"* the values. To do 
so, we need to define the ratio between our types and get the common 
type of the values. To get the ratio between the types, we can divide them 
with [`std::ratio_divide`][5]:
```cpp
using ratio_t = typename std::ratio_divide<IN_RATIO_T, OUT_RATIO_T>::type;
```

For the detection of the common type, we can use [`std::common_type`][6]: 
```cpp
using common_t = typename std::common_type_t<IN_VALUE_T, OUT_VALUE_T, std::intmax_t>;
```

The last step would be to calculate the new value based on our common types:
```cpp
const auto out_value = in_value * static_cast<common_t>(ratio_t::num) /
                                  static_cast<common_t>(ratio_t::den);
```

And if we put everything together, it will look like this[^4]:

```cpp
template <typename TARGET_DISTANCE_T, typename VALUE_T, typename RATIO_T>
constexpr auto distance_cast(
    const distance<VALUE_T, RATIO_T>& distance) noexcept -> TARGET_DISTANCE_T {
    using out_ratio_t = typename detail::ratio_t<TARGET_DISTANCE_T>::type;
    using ratio_t =typename std::ratio_divide<RATIO_T, out_ratio_t>;
    using out_value_t = typename detail::value_t<TARGET_DISTANCE_T>;
    using common_t = typename std::common_type_t<VALUE_T, out_value_t, std::intmax_t>;

    const auto in_value = underlying_value(distance);
    const auto out_value = in_value * static_cast<common_t>(ratio_t::num) /
                                      static_cast<common_t>(ratio_t::den);
    return TARGET_DISTANCE_T{static_cast<out_value_t>(out_value)};
}
```

The usage of this would be similar to the use of [`std::duration_cast`][4]:

```cpp
constexpr nautical_mile nm(1);
constexpr auto m = distance_cast<meter>(nm);
static_assert(underlying_value(m) == 1'852);
```

### Notes about Generalization

It is possible to generalize operations between strong types. So it would be 
easy to implement a generic cast for strong types or to add generic 
possibilities for operations like addition or comparison, but they are not 
helpful in every context. So it would have some use to add two distances with each 
other, but it could be an error if you allow the same with identifiers.

If we want to provide this functionality, the easiest way would be with traits 
over the tag type. This could look like the following[^5]:

```cpp
namespace detail {
template <typename>
struct addition_allowed : std::false_type {};

template <>
struct addition_allowed<distance_tag> : std::true_type {};

template <typename T>
inline constexpr auto addition_allowed_v = addition_allowed<T>::value;
}  // namespace detail

template <typename VALUE_T, typename TAG_T, typename RATIO_T>
    requires detail::addition_allowed_v<TAG_T>
constexpr auto operator+(const strong_type<VALUE_T, TAG_T, RATIO_T>& lhs, 
                         const strong_type<VALUE_T, TAG_T, RATIO_T>& rhs) 
-> strong_type<VALUE_T, TAG_T, RATIO_T> {
    return strong_type<VALUE_T, TAG_T, RATIO_T>{underlying_value(lhs) +
                                                underlying_value(rhs)};
}
```

## Summary

Strong types are valuable to enhance type safety and make the code 
more expressive and self-documenting. By employing tag types and encapsulation, 
we can create distinct types based on the same underlying value type, preventing 
unintended conversions and improving code clarity. It also allows us to provide 
generalized operations between convertible types like for physical units.

Embracing strong types is a step toward writing cleaner, safer, and more 
maintainable C++ code, ultimately leading to a more enjoyable and productive 
development experience.[^1]

## References

### Blogs

* [Fluent {C++}][3]: [Strongly typed constructors](https://www.fluentcpp.com/2016/12/05/named-constructors/)
* [Fluent {C++}][3]: [Strong types for strong interfaces](https://www.fluentcpp.com/2016/12/08/strong-types-for-strong-interfaces/)
* [Fluent {C++}][3]: [NamedType: The Easy Way to Use Strong Types in C++](https://embeddedartistry.com/blog/2018/04/23/namedtype-the-easy-way-to-use-strong-types-in-c/)
* [Fluent {C++}][3]: [Strong Units Conversions](https://www.fluentcpp.com/2017/05/26/strong-types-conversions/)

### Videos

* Richárd Szalay: CppNow 2023 [Migration to Strong Types in C++: Interactive Tooling Support](https://youtu.be/rcXf1VCA1Uc)

### Code

* Implementation of strong types by [Jonathan Boccara][3]: [NamedType](https://github.com/joboccara/NamedType)
* Strong types with customizing behavior: [strong_type](https://github.com/doom/strong_type)

## Footnotes

[^1]: The use of strong types is also recommended by the [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#Ri-typed)
[^2]: compiler explorer link: [https://godbolt.org/z/KKW1fdfvc](https://godbolt.org/z/KKW1fdfvc)
[^3]: compiler explorer link: [https://godbolt.org/z/3rGdjWjfd](https://godbolt.org/z/3rGdjWjfd)
[^4]: compiler explorer link: [https://godbolt.org/z/G71a18cn9](https://godbolt.org/z/G71a18cn9)
[^5]: compiler explorer link: [https://godbolt.org/z/MfhE9GsGz](https://godbolt.org/z/MfhE9GsGz)

[1]: https://en.cppreference.com/w/cpp/header/chrono
[2]: https://en.cppreference.com/w/cpp/chrono/duration
[3]: https://www.fluentcpp.com/
[4]: https://en.cppreference.com/w/cpp/chrono/duration/duration_cast
[5]: https://en.cppreference.com/w/cpp/numeric/ratio/ratio_divide
[6]: https://en.cppreference.com/w/cpp/types/common_type
