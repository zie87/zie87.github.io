---
layout: post
title: 'Reinventing the Wheel: Type Sequences'
date: '2023-05-27 17:29:39'
categories: ['C++', 'Reinventing the Wheel']
tags: ['c++', 'type traits', 'meta programming']
---

I needed to implement a type list three times today. On three different 
occurrences, I needed to implement it in [compiler explorer][1] to show how to 
handle operations on [variadic template parameters][2]. As much as I appreciate 
the exercise, I recognized that it could make sense to create a post, which I 
can use as a base for discussion in the future.

So what is a type sequence? A type sequence is a compile-time sequence of 
types used as a base for template metaprogramming. In the past, multiple 
implementations for such sequences existed to allow using a variable amount of 
template arguments.[^1] The most common was a so-called *type list*. Then, C++11 
introduced variadic template arguments. Since then, most libraries[^2] have 
provided a sequence type based directly on variadic template parameters.

## The Sequence Type

Creating such a type is as simple as it could be. We only need the following lines:

```cpp
template <typename ... Ts>
struct sequence {};
```

That's all. We now can use it as a base to repack variadic template 
arguments and make operations over these types. To make the use a little bit 
easier, let's define some utilities:

```cpp
#include <type_traits>

template <typename>
struct is_sequence : std::false_type {};

template <typename ... Ts>
struct is_sequence<sequence<Ts...>> : std::true_type {};

template <typename T>
inline constexpr bool is_sequence_v = is_sequence<T>::value;
```

These lines define a trait to detect if a given type is, in fact, a sequence. 
To do so is quite simple. We only need to define the trait itself, which is a 
`std::false_type` for everything which is not specialized and on specialization 
for out sequence type, which will be a `std::true_type`. With this in place we 
can define use a [concept][6]:

```cpp
namespace concepts {
 template <typename T>
 concept sequence = ::is_sequence_v<T>;
}
```

With this [concept][6], we can now easily define that we need a sequence as a 
template parameter.

## Calculating the Size

To calculate the size, we can use the [`sizeof... operator`][7]:

```cpp
template <typename>
struct size;

template <typename... Ts>
struct size<sequence<Ts...>>
    : std::integral_constant<std::size_t, sizeof...(Ts)> {};

template <typename T>
inline constexpr auto size_v = size<T>::value;
```

We inherit from [`std::integral_constant`][8] to provide an API, which is 
compatible with other traits. We can also test if everything works like 
expected with [static assertions][9]:

```cpp
static_assert(size_v<sequence<>> == 0);
static_assert(size_v<sequence<char, short, int>> == 3);
```

With this in place, the implementation of empty is a piece of cake:

```cpp
template <concepts::sequence SEQ_T>
struct empty : std::bool_constant<(size_v<SEQ_T> == 0)> {};

template <concepts::sequence SEQ_T>
inline constexpr auto empty_v = empty<SEQ_T>::value;
```

Here we do not need the variadic template parameters directly, so we can use 
our *sequence concept* to define the input parameter. Then, to determine the value, we 
check if the `size_v` is zero, and that's the implementation of the `empty` trait. 

## Indexed Access

Now we implement something more interesting: fetch a type by index. Let's start 
with the signature:

```cpp
template <concepts::sequence SEQ_T, std::size_t IDX_V>
struct at {
    static_assert(IDX_V < size_v<SEQ_T>, "index out of bounce!");
    using type = typename detail::at_helper<SEQ_T, IDX_V>::type;
};

template <concepts::sequence SEQ_T, std::size_t IDX_V>
using at_t = typename at<SEQ_T, IDX_V>::type;
```

The defined template needs a sequence and an index as a template parameter. The 
[static assertions][9] helps to detect out-of-bound access. The target type will 
be evaluated by helper types with a template recursion:

```cpp
namespace detail {
template <typename, std::size_t>
struct at_helper;

template <typename HEAD_T, typename... Ts>
struct at_helper<sequence<HEAD_T, Ts...>, 0> {
    using type = HEAD_T;
};

template <typename HEAD_T, typename... Ts, std::size_t IDX_V>
struct at_helper<sequence<HEAD_T, Ts...>, IDX_V> {
    using type = typename at_helper<sequence<Ts...>, (IDX_V - 1)>::type;
};
}  // namespace detail
```

The helper will "cut the head" of the sequence and then calls itself with the 
index reduced by one. This recursion will go on until the index is zero. At 
this point, the current `HEAD_T` is the type we are searching for, and we 
are done.

But does it work? Let's test the implementation:

```cpp
using at_test_seq = sequence<char, short, int, double, int>;
static_assert(std::is_same_v<at_t<at_test_seq, 0>, char>);
static_assert(std::is_same_v<at_t<at_test_seq, 1>, short>);
static_assert(std::is_same_v<at_t<at_test_seq, 2>, int>);
static_assert(std::is_same_v<at_t<at_test_seq, 3>, double>);
static_assert(std::is_same_v<at_t<at_test_seq, 4>, int>);

// does not build: index out of bounds
// static_assert(std::is_same_v< at_t<at_test_seq, 5>, int >);
```

We can check if the type matches our expectation with [`std::is_same`][10]. 
If it compiles, this means we have done everything right. So we can proceed.

## Search in the Sequence

Finding the index of the first occurrence of a type in the sequence is a classic 
linear search, which we also can implement with a template recursion. The signature 
is similar to what we have already done: 

```cpp
template <concepts::sequence SEQ_T, typename T>
struct index_of
    : std::integral_constant<std::size_t,
                             detail::idx_of_helper<SEQ_T, T>::value> {};

template <concepts::sequence SEQ_T, typename T>
inline constexpr auto index_of_v = index_of<SEQ_T, T>::value;
```

We accept a sequence and the type we are searching for. The `struct` inherits 
from and [`integral_constant`][8], where the value is calculated with some 
helpers:

```cpp
namespace detail {
template <typename, typename>
struct idx_of_helper;

template <typename T>
struct idx_of_helper<sequence<>, T> {
    static_assert(false, "sequence does not contain the type!");
};

template <typename T, typename... Ts>
struct idx_of_helper<sequence<T, Ts...>, T> {
    static constexpr std::size_t value = 0;
};

template <typename T, typename HEAD_T, typename... Ts>
struct idx_of_helper<sequence<HEAD_T, Ts...>, T> {
    static constexpr std::size_t value =
        1 + idx_of_helper<sequence<Ts...>, T>::value;
};
}  // namespace detail
```

The helper calls himself recursively, similar to `at_helper`, where each 
recursive call will add one to the index value. When the `HEAD_T` is equal to 
the type we are searching for, we stop the recursion and set the value to zero. 
If the sequence does not contain the type, we will hit the specialization for 
an empty sequence. Then we catch this error with a static assertion. 

The only thing which is left is to write some tests, and then we can go on:

```cpp
using idx_test_seq = sequence<char, short, int, double, int>;
static_assert(index_of_v<idx_test_seq, char> == 0);
static_assert(index_of_v<idx_test_seq, int> == 2);
static_assert(index_of_v<idx_test_seq, double> == 3);
```

We should also add an option to determine if the sequence contains a type. To 
do so, we define helpers and utilize [`std::disjunction`][11]:

```cpp
namespace detail {
template <typename, typename>
struct contains_helper;

template <typename T, typename... Ts>
struct contains_helper<sequence<Ts...>, T>
    : std::disjunction<std::is_same<T, Ts>...> {};

}  // namespace detail
```

The trait can now inherit from the helper to define his value:

```cpp
template <concepts::sequence SEQ_T, typename T>
struct contains : detail::contains_helper<SEQ_T, T> {};

template <concepts::sequence SEQ_T, typename T>
inline constexpr auto contains_v = contains<SEQ_T, T>::value;

static_assert(contains_v<idx_test_seq, char>);
static_assert(contains_v<idx_test_seq, int>);
static_assert(!contains_v<idx_test_seq, long>);
```

## Extend the Sequence

The implementation of `push_back` and `push_front` for a sequence is quite simple:

```cpp
namespace detail {
template <typename, typename>
struct push_front_helper;

template <typename... Ts, typename T>
struct push_front_helper<sequence<Ts...>, T> {
    using type = sequence<T, Ts...>;
};

template <typename, typename>
struct push_back_helper;

template <typename... Ts, typename T>
struct push_back_helper<sequence<Ts...>, T> {
    using type = sequence<Ts..., T>;
};
}  // namespace detail
```

This helper extracts the types the sequence already contains and then 
defines a new sequence with this type and the new type on the desired position. 
The signature definition is only the call to the matching helper:

```cpp
template <concepts::sequence SEQ_T, typename T>
struct push_front {
    using type = typename detail::push_front_helper<SEQ_T, T>::type;
};

template <concepts::sequence SEQ_T, typename T>
using push_front_t = typename push_front<SEQ_T, T>::type;

template <concepts::sequence SEQ_T, typename T>
struct push_back {
    using type = typename detail::push_back_helper<SEQ_T, T>::type;
};

template <concepts::sequence SEQ_T, typename T>
using push_back_t = typename push_back<SEQ_T, T>::type;
```

Let's make something more interesting: the concatenation of any amount of sequences.
We begin with a concatenation of two sequences. This code can reach this:

```cpp
namespace detail {
template <typename, typename>
struct cat_helper;

template <typename... LTs, typename... RTs>
struct cat_helper<sequence<LTs...>, sequence<RTs...>> {
    using type = sequence<LTs..., RTs...>;
};
}  // namespace detail
```

The `cat_helper` struct extracts the types from both sequences and combines 
them in a new sequence definition. Now that we can combine two sequences, we 
can combine any amount by combining two recursively. For this, we need to change 
the forward definition of the helper and add two additional cases:
1. concatenation of only one sequence
2. concatenation of any number of sequences

```cpp
namespace detail {
template <typename...>
struct cat_helper;

template <typename... Ts>
struct cat_helper<sequence<Ts...>> {
    using type = sequence<Ts...>;
};

template <typename... LTs, typename... RTs>
struct cat_helper<sequence<LTs...>, sequence<RTs...>> {
    using type = sequence<LTs..., RTs...>;
};

template <concepts::sequence SEQ_T, concepts::sequence... SEQ_Ts>
struct cat_helper<SEQ_T, SEQ_Ts...> {
    using tail_type = typename cat_helper<SEQ_Ts...>::type;
    using type = typename cat_helper<SEQ_T, tail_type>::type;
};
}  // namespace detail
```

The first case is an additional stop condition for the recursion. The type of 
concatenation with only one sequence is the sequence itself. For any number of 
sequences, we need to concatenate the first sequence with the concatenations of 
all other cases.

The signature needs only to call the helper:

```cpp
template <concepts::sequence... SEQ_Ts>
struct cat {
    using type = typename detail::cat_helper<SEQ_Ts...>::type;
};

template <concepts::sequence... SEQ_Ts>
using cat_t = typename cat<SEQ_Ts...>::type;
```

And that's it. We can now concatenate any amount of sequences:

```cpp
using cat_test_seq1 = sequence<char, int>;
using cat_test_seq2 = sequence<short, double>;
static_assert(std::is_same_v<cat_t<cat_test_seq1, cat_test_seq2>,
                             sequence<char, int, short, double>>);
static_assert(std::is_same_v<cat_t<cat_test_seq1, cat_test_seq2, cat_test_seq1>,
                             sequence<char, int, short, double, char, int>>);
```

## Remove from a Sequence

Now we can add additional types to sequences, so it is time to add the opposite 
operation: remove a type from a sequence. To remove a type, we search for the 
type with a recursion, similar to the search for the index of a type. 
The helpers look like this:

```cpp
namespace detail {
template <typename, typename>
struct remove_helper;

template <typename T>
struct remove_helper<sequence<>, T> {
    using type = sequence<>;
};

template <typename... Ts, typename T>
struct remove_helper<sequence<T, Ts...>, T> {
    using type = sequence<Ts...>;
};

template <typename HEAD_T, typename... Ts, typename T>
struct remove_helper<sequence<HEAD_T, Ts...>, T> {
    using tail_type = typename remove_helper<sequence<Ts...>, T>::type;
    using type = push_front_t<tail_type, HEAD_T>;
};
}  // namespace detail
```

The primary helper makes the recursive call. For the recursion, we have two 
stop conditions:
1. we have no value to check anymore (an empty sequence)
2. we found the first match

This helper will now remove the first occurrence of a type in the sequence. The 
API must now use these helpers:

```cpp
template <concepts::sequence SEQ_T, typename T>
struct remove_first {
    using type = typename detail::remove_helper<SEQ_T, T>::type;
};

template <concepts::sequence SEQ_T, typename T>
using remove_first_t = typename remove_first<SEQ_T, T>::type;
```

Now we can remove the first match for a given type. We again can check this 
with the use of [static assertions][9]:

```cpp
using rm_test_seq = sequence<char, int, float>;
static_assert(std::is_same_v<remove_first_t<rm_test_seq, float>, sequence<char, int>>);
static_assert(std::is_same_v<remove_first_t<sequence<>, float>, sequence<>>);
static_assert(std::is_same_v<remove_first_t<sequence<char, int>, float>, sequence<char, int>>);
```

If we want to remove all occurrences of a type, we only need to adapt the helper 
to a recursive call after the first remove:

```cpp
template <typename... Ts, typename T>
struct remove_all_helper<sequence<T, Ts...>, T> {
    using type = typename remove_all_helper<sequence<Ts...>, T>::type;
};
```

With this, the helpers look like this:

```cpp
namespace detail {
template <typename, typename>
struct remove_all_helper;

template <typename T>
struct remove_all_helper<sequence<>, T> {
    using type = sequence<>;
};

template <typename... Ts, typename T>
struct remove_all_helper<sequence<T, Ts...>, T> {
    using type = typename remove_all_helper<sequence<Ts...>, T>::type;
};

template <typename HEAD_T, typename... Ts, typename T>
struct remove_all_helper<sequence<HEAD_T, Ts...>, T> {
    using tail_type = typename remove_all_helper<sequence<Ts...>, T>::type;
    using type = push_front_t<tail_type, HEAD_T>;
};
}  // namespace detail
```

The public API is quite similar to `remove_first`:

```cpp
template <concepts::sequence SEQ_T, typename T>
struct remove_all {
    using type = typename detail::remove_all_helper<SEQ_T, T>::type;
};

template <concepts::sequence SEQ_T, typename T>
using remove_all_t = typename remove_all<SEQ_T, T>::type;
```

```
static_assert(std::is_same_v<remove_all_t<sequence<char, int, float, float, int, float>, float>, 
                             sequence<char, int, int>>);
```

## Remove Duplicates

An often-needed operation on type sequences is to remove all duplicates. We can 
solve this also with a template recursion. The implementation for the helpers 
can look like this:

```cpp
namespace detail {
template <typename>
struct unique_helper;

template <>
struct unique_helper<sequence<>> {
    using type = sequence<>;
};

template <typename HEAD_T, typename... Ts>
struct unique_helper<sequence<HEAD_T, Ts...>> {
    using temp_type = remove_all_t<sequence<Ts...>, HEAD_T>;
    using tail_type = typename unique_helper<temp_type>::type;
    using type = push_front_t<tail_type, HEAD_T>;
};
}  // namespace detail
```

The specialization for the empty sequence stops our recursion. The real 
processing needs three steps:
1. delete the head from the tail (`temp_type`)
2. repeat this step for the next element via recursion (`tail_type`)
3. combine the head with the cleaned tail (` using type = push_front_t<tail_type, HEAD_T>;`)

The public API is simple and needs only the *sequence* as a template parameter:
```cpp
template <concepts::sequence SEQ_T>
struct unique {
    using type = typename detail::unique_helper<SEQ_T>::type;
};

template <concepts::sequence SEQ_T>
using unique_t = typename unique<SEQ_T>::type;
```

These assertions show how we can use our new `unique` functionality:

```cpp
static_assert(std::is_same_v<unique_t<sequence<>>, sequence<>>);
static_assert(std::is_same_v<unique_t<sequence<int, char, int, char, char, float>>,
                             sequence<int, char, float>>);
```

## Replace Elements in a Sequence

Another typical operation on sequences is the replacement of types. The 
algorithm to replace types is nearly identical to the erase. The only 
difference is that the matching overload removes and injects the new type into 
the position. In code, this means this helper:

```cpp
template <typename... Ts, typename HEAD_T>
struct remove_helper<sequence<HEAD_T, Ts...>, HEAD_T> {
    using type = sequence<Ts...>;
};
```

Needs to be changed to this helper:

```cpp
template <typename... Ts, typename HEAD_T, typename U>
struct replace_first_helper<sequence<HEAD_T, Ts...>, HEAD_T, U> {
    using type = sequence<U, Ts...>;
};
```

All other helpers will look the same except for the changed template parameters. 
So all helpers together will look like this:

```cpp
namespace detail {
template <typename, typename, typename>
struct replace_first_helper;

template <typename T, typename U>
struct replace_first_helper<sequence<>, T, U> {
    using type = sequence<>;
};

template <typename... Ts, typename HEAD_T, typename U>
struct replace_first_helper<sequence<HEAD_T, Ts...>, HEAD_T, U> {
    using type = sequence<U, Ts...>;
};

template <typename... Ts, typename HEAD_T, typename T, typename U>
struct replace_first_helper<sequence<HEAD_T, Ts...>, T, U> {
    using tail_type = typename replace_first_helper<sequence<Ts...>, T, U>::type;
    using type = push_front_t<tail_type, HEAD_T>;
};
}  // namespace detail
```

The signatures will also be nearly identical, except for the additional 
template parameter:

```cpp
template <concepts::sequence SEQ_T, typename T, typename U>
struct replace_first {
    using type = typename detail::replace_first_helper<SEQ_T, T, U>::type;
};

template <concepts::sequence SEQ_T, typename T, typename U>
using replace_first_t = typename replace_first<SEQ_T, T, U>::type;

static_assert(std::is_same_v<replace_first_t<sequence<float, char, char>, char, int>,
                             sequence<float, int, char>>);
```

The same is true for `replace_all`: Like for the `remove_all`, it is nearly 
identical to the first version except for the additional recursion in the 
matching case. 

```cpp
namespace detail {
template <typename, typename, typename>
struct replace_all_helper;

template <typename T, typename U>
struct replace_all_helper<sequence<>, T, U> {
    using type = sequence<>;
};

template <typename... Ts, typename HEAD_T, typename U>
struct replace_all_helper<sequence<HEAD_T, Ts...>, HEAD_T, U> {
    using tail_type = typename replace_all_helper<sequence<Ts...>, HEAD_T, U>::type;
    using type = push_front_t<tail_type, U>;
};

template <typename... Ts, typename HEAD_T, typename T, typename U>
struct replace_all_helper<sequence<HEAD_T, Ts...>, T, U> {
    using tail_type = typename replace_all_helper<sequence<Ts...>, T, U>::type;
    using type = push_front_t<tail_type, HEAD_T>;
};
}  // namespace detail
```

```cpp
template <concepts::sequence SEQ_T, typename T, typename U>
struct replace_all {
    using type = typename detail::replace_all_helper<SEQ_T, T, U>::type;
};

template <concepts::sequence SEQ_T, typename T, typename U>
using replace_all_t = typename replace_all<SEQ_T, T, U>::type;

static_assert(std::is_same_v<replace_all_t<sequence<float, char, char>, char, int>,
                             sequence<float, int, int>>);
```
## Summary

This post shows how to implement a type sequence with modern C++ quickly. If 
you want to try the complete code, you can do so in [compiler explorer][12].

## References

### Books 

* Andrei Alexandrescu: *Modern C++ Design - Generic Programming and Design Pattern Applied* (2000)
* David Vandervoorde: *C++ Templates - The Complete Guide* (2018)
* Marius Bancila: *Template Metaprogramming with C++* (2022)

## Footnotes
[^1]: [Boost::MPL][3] for examples provides list, vector, queue, and map types
[^2]: Such libraries are for example [Boost::Mp11][4] or [Brigand][5]

[1]: https://godbolt.org/
[2]: https://en.cppreference.com/w/cpp/language/parameter_pack
[3]: https://www.boost.org/doc/libs/1_82_0/libs/mpl/doc/index.html
[4]: https://www.boost.org/doc/libs/1_82_0/libs/mp11/
[5]: https://github.com/edouarda/brigand
[6]: https://en.cppreference.com/w/cpp/language/constraints
[7]: https://en.cppreference.com/w/cpp/language/sizeof...
[8]: https://en.cppreference.com/w/cpp/types/integral_constant
[9]: https://en.cppreference.com/w/cpp/language/static_assert
[10]: https://en.cppreference.com/w/cpp/types/is_same
[11]: https://en.cppreference.com/w/cpp/types/disjunction
[12]: https://godbolt.org/z/To77v7Mzj
