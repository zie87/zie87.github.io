---
layout: 'post'
title: 'Type Erasure in C++: Polymorphism without Inheritance'
date: '2023-05-20 21:55:44'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure']
---

At CppCon 2019 John Bandela hold a talk titled ["Polymorphism != Virtual"][1]. 
In this talk he describes his takes on Sean Parents points about polymorphism.[^1]
What he tries to archive is to combine the overloading of static polymorphism 
with specific interfaces. The general idea is to create an erasure together 
with a vtable. He created a sample implementation called [polymorphic][2] for 
this approach. Let's take a look how it works.

## The Implementation



## References

### Videos

* John Bandela: CppCon 2019 [“Polymorphism != Virtual: Easy, Flexible Runtime Polymorphism Without Inheritance”][1]

## Footnotes
[^1]: TODO: add link to other post

[1]: https://youtu.be/PSxo85L2lC0
[2]: https://github.com/google/cpp-from-the-sky-down/blob/master/metaprogrammed_polymorphism/polymorphic.hpp
