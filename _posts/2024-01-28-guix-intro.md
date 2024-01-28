---
layout: 'post'
title: 'GNU Guix: An Introduction'
date: '2024-01-28 16:05:00'
categories: ['Guix' ]
tags: ['guix', 'nix', 'gnu', 'linux', 'functional', 'scheme', 'guile']
---

I have been going down the rabbit hole of functional package managers in the last few months and have nuked my system multiple times. I started with [NixOS][13], which I used for about a month until I decided to try out [GNU Guix][1]. And now my tower and my laptop are running [Guix System][1] as their operating system, and [guix][1] is the primary package manager I use inside my [wsl](https://learn.microsoft.com/en-us/windows/wsl/) for work. This tool is excellent and drastically improved my Linux experience. In this blog post, I briefly overview some of the basic features [GNU Guix][1] provides.

## What is GNU Guix?

[GNU Guix][1] is an advanced package manager for GNU Systems. As such, it provides all the core functionalities of a package manager. It allows you to create packages from the source, handle build and runtime dependencies, and install, update, and remove packages on your system. But it also provides additional features that set [GNU Guix][1] apart from more common package managers like apt, dnf, or pacman.

## Functional Packaging

[GNU Guix][1] is a _purely functional package manager_. This means that packages are treated like values in functional programming languages. They are created by functions that receive the dependencies as ***inputs***. These functions do not have any side effects, which means the _same_ inputs make the _same_ packages every time. Once one input changes (e.g., new library version), it will generate a different package (***output***). The functions representing the build instructions are called [***derivations***][4].

![fn-package](/assets/img/guix/fn_package.png)
_functional packaging_

[GNU Guix][1] stores the created packages in the [***store***][9]; the default location for this is `/gnu/store.` Each package gets its unique subdirectory, where the directory name follows the pattern: ***{unique_id}-{package_name}-{package_version}***. So the package for [GNU Hello][5] is stored in `/gnu/store/6fbh8phmp3izay6c0dpggpxhcjn4xlm5-hello-2.12.1/`, where `/gnu/store/` is the default location of the store, `6fbh8phmp3...` is the unique id, `hello` is the package name and `2.12.1` is the package version. The exciting thing about the name is the unique identifier. This identifier is a cryptographic hash of the package's build dependency graph. So, the identifier captures all dependencies. The package will be created in a different directory if a dependency changes. 

This approach for storing the packages violates the [Filesystem Hierarchy Standard (FHS)][6] but also enables a lot of the powerful features [GNU Guix][1] provides.

## Keep your version 

The isolation of a package in its own directory allows you to keep multiple versions of the same package simultaneously. This is also possible if these versions depend on different dependencies because the dependencies are also isolated. The isolation prevents the dependencies and packages from interfering with each other. This approach can stop the dependency hell completely. 

The isolation also creates another benefit: updates of packages cannot break the applications. If dependencies change, a new package will be made, and the old one will be kept untouched.

## Updates and Roll-backs

Have you ever had updates that broke a program you needed? With [GNU Guix][1], you can roll back the update and get your program working again. Package operations never overwrite packages in the store; each new version will have a different path, and the old version is kept untouched. Guix will only create a new ***generation*** of your package collection, which will link the latest versions of your programs. 

If generation does not work out for you, you can execute `guix package --roll-back`, and [GNU Guix][1] will put you back on the previous generation of your software. You can also see all generations of your system by executing `guix package --list-generations`; if you want to switch to a different generation of your software, you can do so with `guix package --switch=generation=[PATTERN]`.

Additionally, all generation switches are transactional; this also includes updates. So, an update interruption will not break the system because everything changes only when the update is completely finished.

## Each user what he wants

[GNU Guix][1] also allows unprivileged package installation. Each user can have one or more [***profiles***][7], which are sets of packages in the store. Only the packages of the active profile will appear in the user's environment. Profiles allow users to install their favorite applications without interfering with another user's environment. The same store entry will be used if multiple users want to use the same package. But if one user updates his version of the package, another can keep their previous version and will not be impacted.

## Transparency

[GNU Guix][1] makes it very easy to see how your packages are built and what dependencies are used for packages. All packages are defined in [Guile][8]. [Guix channels][10] are Guile libraries and provide all necessary information for the package creation. If you want to look at how a package is defined, you can call `guix edit PACKAGE`, so for example, `guix edit hello.` This command will directly open your editor in the package's definition.

If you want to know the dependencies of a package, you can visualize them with [`guix graph`][12]. This command creates the dependency graph for the given package in the input format of [Graphviz][11]. So if you want to create a svg out of the graph, you can directly pass the output to the *dot* command like: `guix graph neovim | dot -Tsvg > neovim_graph.svg`.

![hello-graph](/assets/img/guix/neovim_graph.svg)
_dependency graph for Neovim_

## Summary

The functional packaging approach used by [GNU Guix][1] enables some compelling and innovative features. The reproducibility and the immutable package store reduce the risk of broken packages and allow the crafting of a well-defined environment that adapts perfectly to users' needs. [GNU Guix][1] provides many more features beyond classic package management. In future posts, we will look at how we can define development shells and the complete home configuration with [GNU Guix][1].

## References

### Websites

- [GNU Guix Webside][1]
- [GNU Guix Reference Manual](https://guix.gnu.org/en/manual/en/html_node/)
- [GNU Guix Cookbook](https://guix.gnu.org/en/cookbook/en/html_node/)

### Papers

- Eelco Dolstra 2006: ["The Purely Functional Software Deployment Model"][2]
- Ludovic Courtès 2013: ["Functional Package Management with Guix"][3]


[1]: https://guix.gnu.org/
[2]: https://edolstra.github.io/pubs/phd-thesis.pdf 
[3]: https://arxiv.org/pdf/1305.4584.pdf
[4]: https://guix.gnu.org/manual/en/html_node/Derivations.html
[5]: https://www.gnu.org/software/hello/
[6]: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
[7]: https://guix.gnu.org/cookbook/en/html_node/Guix-Profiles-in-Practice.html
[8]: https://www.gnu.org/software/guile/
[9]: https://guix.gnu.org/manual/en/html_node/The-Store.html
[10]: https://guix.gnu.org/manual/en/html_node/Channels.html
[11]: https://www.graphviz.org/
[12]: https://guix.gnu.org/manual/en/html_node/Invoking-guix-graph.html
[13]: https://nixos.org/
