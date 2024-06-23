---
layout: 'post'
title: 'Loki Revisit: Introduction'
date: '2024-06-22 14:15:00'
categories: ['C++', 'Loki Revisit' ]
tags: ['c++', 'meta programming', 'policy-based design', 'classic', 'modern', 'design pattern']
---

Earlier this year, [CppDepend][6] published some blog posts about the [Loki][3] library and [initiated a challenge][5] to modernize it. Inspired by this initiative, I want to revisit [Loki][3] and explore its potential in today's C++ landscape. Welcome to a new series where we delve into the nuances of this remarkable library.

> Content of this series:
> * [Part 0: Introduction]({% post_url 2024-06-22-loki-intro%})
> * [Part 1: Policy-Based Class Design]({% post_url 2024-06-23-loki-policy%})
{: .prompt-info}

## What is [Loki][3]?

[Loki][3] is a C++ library, developed by [Andrei Alexandrescu][1], which accompanies his book [*Modern C++ Design*][2]. This book was published in 2001 and influenced C++ developers to this day. The book helped to popularize [template metaprogramming][8] and also brought attention to a lot of [idioms][9]. 

The book and library provide a unique take on the classic [design patterns](https://en.wikipedia.org/wiki/Design_Patterns) using a *policy-based class design*. This design makes [Loki][3] different from most libraries; the library is highly configurable and has minimal assumptions about the environment it is used in. This flexibility allows using [Loki][3] in nearly every domain and under every constraint.

This library and the patterns it used influenced the development of [Boost](https://www.boost.org/) and the newer C++ standards (C++11 and upwards). A lot of the functionalities [Loki][3] provides were added to [Boost](https://www.boost.org/) (e.g., function objects, scope guards, type traits) and are now part of the STL. 

With the standardization of C++11, the development of [Loki][3] stopped. There has been no active development of [Loki][3] since 2009, and the library does not built anymore out of the box with the current C++ standards.

## About this series

Over two decades after the first release of [*Modern C++ Design*][2], I'm still fascinated by the book and the [Loki library][3]. I learned a lot by reading the code of this particular project. C++ has changed since 2001, and many of the limitations of the early standards have been lifted. The language now has support for [type traits][10] in the STL, and [variadic templates][11] can be used instead of *type lists*. Also, [template metaprogramming][8] now has support from language features like [`constexpr`][12], [`consteval`][13], and [`constinit`][14]. Since C++20, we can define policies as [`concepts`][15].

The evolution of the language raises the question: *How could Loki now look like?* In this series, we want to answer this question by revisiting [*Modern C++ Design*][2] and reimplementing parts of [Loki][3] with [C++23](https://en.cppreference.com/w/cpp/23). We will explore the original implementation and discuss the historical context of this time by looking into additional articles and publications about C++, together with ancient releases of libraries at this time, such as [Boost](https://www.boost.org/). We will do so by following the structure of [*Modern C++ Design*][2], so stay tuned for our deep dive into [Policy-Based Class Design]({% post_url 2024-06-23-loki-policy%}), the first chapter of this journey.

## References

### Books 

* [Andrei Alexandrescu][1], [*Modern C++ Design - Generic Programming and Design Pattern Applied* (2001)][2]

### Blogs

* [CppDepend][6]: [*Modern C++ Design: Learn with Loki Library*](https://cppdepend.com/blog/modern-cpp-design-learn-with-loki-library/)
* [CppDepend][6]: [*Loki: The Premier C++ Library for Mastering Design Patterns*][4]
* [CppDepend][6]: [*The Modern C++ Challenge*][5]

### Code

* [Loki][3] ([wayback][7]): [github fork](https://github.com/zie87/loki-lib)

[1]: http://erdani.org/index.html
[2]: https://en.wikipedia.org/wiki/Modern_C%2B%2B_Design
[3]: https://sourceforge.net/projects/loki-lib/
[4]: https://cppdepend.com/blog/loki-the-best-c-library-to-learn-design-patterns-lets-modernize-it/
[5]: https://cppdepend.com/blog/c-contest-to-promote-the-new-c-standards/
[6]: https://www.cppdepend.com/
[7]: https://web.archive.org/web/20210211234705/http://loki-lib.sourceforge.net/
[8]: https://en.wikipedia.org/wiki/Template_metaprogramming
[9]: https://en.wikibooks.org/wiki/More_C%2B%2B_Idioms
[10]: https://en.cppreference.com/w/cpp/header/type_traits
[11]: https://en.cppreference.com/w/cpp/language/parameter_pack
[12]: https://en.cppreference.com/w/cpp/language/constexpr
[13]: https://en.cppreference.com/w/cpp/language/consteval
[14]: https://en.cppreference.com/w/cpp/language/constinit
[15]: https://en.cppreference.com/w/cpp/language/constraints
