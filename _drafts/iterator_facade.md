---
layout: post
title: 'Reinventing the Wheel: iterator_facade'
date: '2023-09-30 10:20:35'
categories: ['C++', 'Reinventing the Wheel']
tags: ['c++', 'pattern', 'iterator', 'proposal', 'P2727']
---

If you ever worked with the Standard Template Libary of C++ you will came a 
across iterators. Iterators in the STL are essential for the standard algorithms 
and containers to work and interoperate with each other. The usage of iterators 
as generic concept enables a lot of flexibility and reusablity, but it comes 
also with a price. To write an own iterator which integrates well with the STL 
is suprisingly hard. Luckly there exists a proposal which tries to simplify 
this task: [P2727: `std::iterator_interface`][1].

## Iterator Pattern

Before we dig into to the proposal we should take a look at what an iterator 
pattern is:

Iterator Pattern
: A behavioral design pattern, which provides a way to access the elements of 
an aggregate object sequentially without exposing its underlying representation.[^1]

So an iterator abstracts the representation of data to allow an abstract access 
to this data. This is used in the STL to enable the reuse of algorithms and to 
define an abstract API contract for containers. The STL distinqushes iterators 
by six categories[^2]:
1. [LegacyInputIterator](https://en.cppreference.com/w/cpp/named_req/InputIterator)
1. [LegacyOutputIterator](https://en.cppreference.com/w/cpp/named_req/OutputIterator)
1. [LegacyForwardIterator](https://en.cppreference.com/w/cpp/named_req/ForwardIterator)
1. [LegacyBidirectionalIterator](https://en.cppreference.com/w/cpp/named_req/BidirectionalIterator)
1. [LegacyRandomAccessIterator](https://en.cppreference.com/w/cpp/named_req/RandomAccessIterator)
1. [LegacyContiguousIterator](https://en.cppreference.com/w/cpp/named_req/ContiguousIterator)

Each of these categories provides you a well defined set of member methods and 
guaranties about the used iterator. This information is used to check if 
algorithms can be used or if optimizations are possible. This means if you want 
to provide an own iterator you need to define the proper category for you iterator 
and also implement all necessary methodes and typedef for your iterator to 
fullfill the API and the garantues. A random access iterator for example needs 
to provide following methodes an typedefs[^3]:

```cpp
using value_type = Type;
using reference = value_type&;
using pointer = value_type*;
using difference_type = std::ptrdiff_t;
using iterator_category = std::random_access_iterator_tag;
// using iterator_concept = /*...*/;

reference operator*();
// pointer operator->();
reference operator[](std::size_t index);

iterator& operator++();
iterator operator++(int);
iterator& operator--();
iterator operator--(int);
iterator& operator+=(const difference_type other);
iterator& operator-=(const difference_type other);
iterator operator+(const difference_type other);
iterator operator-(const difference_type other);
iterator operator+(const iterator& other);
difference_type operator-(const iterator& other);

bool operator==(const iterator& other);
// bool operator!=(const iterator& other);
// bool operator<(const iterator& other);
// bool operator>(const iterator& other);
// bool operator<=(const iterator& other);
// bool operator>=(const iterator& other);
```

To implement all this functions for each iterator is quite cumbersome and error 
prune. 

## [`std::iterator_interface`][1]

The [`std::iterator_interface`][1] proposal tries to reduce the needed 
effort to implement such iterator by generalize most of the needed 
functionality. 


## References

### Blogs

* [vector-of-bool][3]: [An `iterator_facade` in C++20][4]

### Paper 

* P2727: [`std::iterator_interface`][1]

### Videos

* Zach Lain: CppCon 2020 [Making Iterators, Views and Containers Easier to Write with `Boost.STLInterfaces`](https://youtu.be/JByCzWaGxhE)


### Code

* [Boost.STLInterfaces][2] base implementation for `iterator_interface`


## Footnotes

[^1]: this definition is based on the classic [GoF design patterns](https://en.wikipedia.org/wiki/Design_Patterns) book 
[^2]: see the [cppreference: Iterator Library](https://en.cppreference.com/w/cpp/iterator)
[^3]: the code commented out is not necessary but more or less expected

[1]: https://wg21.link/p2727r1
[2]: https://github.com/boostorg/stl_interfaces
[3]: https://vector-of-bool.github.io/
[4]: https://vector-of-bool.github.io/2020/06/13/cpp20-iter-facade.html
