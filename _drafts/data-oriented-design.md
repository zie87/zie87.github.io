---
layout: post
title: 'Data-Oriented Design: The Primality of Operand vs Operation'
date: '2023-05-09 20:07:12'
categories: ['Pattern', 'Game Programming']
tags: ['c++', 'data-oriented', 'pattern']
---


## References

### Articles
* [awesome-ecs](https://github.com/jslee02/awesome-entity-component-system)

* Discussion between Casey Muratori and Robert C. Martin (Uncle Bob).[^1] 
* Tobias Stein: [Entity Component System](https://tsprojectsblog.wordpress.com/portfolio/entity-component-system/)
* Tobias Stein: [The Entity-Component-System - C++ Game Design Pattern (Part 1)](https://www.gamedev.net/articles/programming/general-and-gameplay-programming/the-entity-component-system-c-game-design-pattern-part-1-r4803/)
* Tobias Stein: [The Entity-Component-System - BountyHunter game (Part 2)](https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/the-entity-component-system-bountyhunter-game-part-2-r4804/)
* [EnTT in Action](https://github.com/skypjack/entt/wiki/EnTT-in-Action)
* [The C++ of EnTT](https://skypjack.github.io/pdf/the_cpp_of_entt.pdf)
* [Test For Parallel Processing Of Components](http://entity-systems.wikidot.com/test-for-parallel-processing-of-components#cpp)
* [ES Tutorials](http://entity-systems.wikidot.com/es-tutorials)
* [A simple Entity Component System](https://austinmorlan.com/posts/entity_component_system/)
* [An Entity-Component-System From Scratch](https://www.codingwiththomas.com/blog/an-entity-component-system-from-scratch)
* [How to make a simple entity-component-system in C++](https://www.david-colson.com/2020/02/09/making-a-simple-ecs.html)
* [An Entity Component System in C++ with Data Locality](https://indiegamedev.net/2020/05/19/an-entity-component-system-with-data-locality-in-cpp/)
* [Introduction to Entity Component System](https://dean-j-k-james.medium.com/introduction-to-entity-component-system-64c371f274bd)

* [Understanding Component-Entity-Systems](https://web.archive.org/web/20220118154525/https://www.gamedev.net/tutorials/_/technical/game-programming/understanding-component-entity-systems-r3013/)
* [Implementing Component-Entity-Systems](https://web.archive.org/web/20200801075022/https://www.gamedev.net/tutorials/_/technical/game-programming/implementing-component-entity-systems-r3382/)

* [Entity Systems are the future of MMOG development – Part 1](https://web.archive.org/web/20230208032643/http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/)
* [Data Structures for Entity Systems: Contiguous memory](https://t-machine.org/index.php/2014/03/08/data-structures-for-entity-systems-contiguous-memory/)
* [Entity Systems: what makes good Components? good Entities?](https://t-machine.org/index.php/2012/03/16/entity-systems-what-makes-good-components-good-entities/)
* [Designing Bomberman with an Entity System: Which Components?](https://web.archive.org/web/20221204040710/https://t-machine.org/index.php/2013/05/30/designing-bomberman-with-an-entity-system-which-components/)

* [Case Study: Bomberman Mechanics in an Entity-Component-System](https://web.archive.org/web/20221028003441/https://www.gamedev.net/tutorials/_/technical/game-programming/case-study-bomberman-mechanics-in-an-entity-component-system-r3159/)
* [Nomad Game Engine](https://savas.ca/nomad)

* Mick West: [Evolve Your Hierarchy: Refactoring Game Entities with Components](https://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)

* Randy Gaul: [Component Based Engine Design](https://web.archive.org/web/20141010145330/http://www.randygaul.net/2013/05/20/component-based-engine-design/)
* Randy Gaul: [Sane Usage of Components and Entity Systems](https://web.archive.org/web/20141011213919/http://www.randygaul.net/2014/06/10/sane-usage-of-components-and-entity-systems)

* Noel: [Data-Oriented Design (Or Why You Might Be Shooting Yourself in The Foot With OOP)](https://gamesfromwithin.com/data-oriented-design)

* Jungwan Byun: [Data-oriented Entity Component System](https://raw.githubusercontent.com/fastbird/doecs/master/doecs_v1.0.pdf)
* Toni Härkönen: [Advantages and Implementation of Entity-Component-Systems](https://trepo.tuni.fi/bitstream/handle/123456789/27593/H%C3%A4rk%C3%B6nen.pdf)

### Books

* Richard Fabian: [*Data-oriented Design*][1] 

### Videos

* Mike Acton: CppCon 2014 ["Data-Oriented Design and C++"](https://youtu.be/rX0ItVEVjHc)
* Stoyan Nikolov: CppCon 2018 ["OOP Is Dead, Long Live Data-oriented Design"](https://youtu.be/yy8jQgmhbAU)
* Casey Muratori: ["Clean" Code, Horrible Performance](https://youtu.be/tD5NrevFtbU)

### Libraries

* [EnTT: Gaming meets modern C++](https://github.com/skypjack/entt)
* [ecst: Experimental C++14 multithreaded compile-time entity-component-system library](https://github.com/vittorioromeo/ecst)

## Footnotes 

[^1]: you can read the discussion on [github](https://github.com/cmuratori/misc/tree/main)

[1]: https://www.dataorienteddesign.com/dodbook/
