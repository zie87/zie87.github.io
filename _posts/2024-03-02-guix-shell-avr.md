---
layout: 'post'
title: 'GNU Guix: Development Shell for Arduino'
date: '2024-03-02 16:05:00'
categories: ['Guix' ]
tags: ['guix', 'nix', 'gnu', 'linux', 'functional', 'scheme', 'guile', 'arduino', 'arduino uno', 'arduino nano', 'atmel', 'embedded', 'meson', 'just']
---

I'm still very much in love with [GNU Guix][1], and there is one feature I enjoy in particular: [`guix shell`][2]. I like this feature so much that I will use this post to introduce it briefly. To do so, I will revisit an older post about setting up a [development environment for Arduino][3].

## What is a `guix shell`?

At first, we need to define what a [`guix shell`][2] is or what this command does. By invoking the command [`guix shell`][2], [GNU Guix][1] will create a *one-off software environment*. So, this command creates a shell environment with a given set of packages installed without touching your profile. After the shell is closed, the programs will not be in the environment anymore and can directly be removed by the [Garbage Collector][4]. This behavior makes it a great tool to test software. If you want to test, for example, the [GNU Hello][5] program, you can do so with:

```bash
guix shell hello -- hello
```

This command creates a new software environment with the package [`hello`][5] installed and then executes the program [`hello`][5] directly and closes the shell after execution. The command itself contains here out of two parts separated by `--`. The first part, `guix shell hello,` defines what the shell should provide, in this case only [`hello`][5]. The parameter `--` specifies the command that should be executed in the shell, so `-- hello` means: *run the hello program*.

Such a shell is handy for executing programs you do not want to have in your environment or do not need regularly. For example, I do not use [GNU Octave][6] regularly, but every few years, I need to use it to execute a script written in [Matlab][7] or test some calculations. So, if I want to generate some random numbers with [GNU Octave][6], I can run:

```bash
guix shell octave -- octave --eval "rand(3, 2)"
```

After my random numbers are created, I can forget about [GNU Octave][6] again; it is not considered for updates, his dependencies will not pollute my library paths, and [`guix gc`][4] can remove it on its next run automatically.

## Setup a toolchain with `guix shell`

Now we look where [`guix shell`][2] shines: toolchains and development environments. Last year, I wrote a [post][3] on how to set up a development environment for Arduino with [Docker][7]. We can create a similar environment using [`guix shell`][2] instead.

First, we need to recap what we need. We will use the same source code and build tools as last time. The tools we need are:
1. a toolchain for AVR
1. [Meson][9] and [Ninja][10] for the build system 
1. [AVRDUDE][11] to flash the software on the device

Let us take a look at the toolchain. [GNU Guix][1] provides the toolchain already as a package called `gcc-cross-avr-toolchain`. This package gives us the [GNU Binutils](https://www.gnu.org/software/binutils/), the [GNU Compiler Collection](https://gcc.gnu.org/), and the [AVR libc](https://www.nongnu.org/avr-libc/) for AVR Microprocessors.[^1]

For our build system, we need [Meson][9] and [Ninja][10]; the packages are accordingly called: `meson` and `ninja.` The last missing piece is [AVRDUDE][11]. For this tool, we need to install the `avrdude` package.

With the packages defined, we can invoke [`guix shell`][2] with this command:

```bash
guix shell gcc-cross-avr-toolchain meson ninja avrdude
```

By invoking this command, we only provide the list of packages we want available and **not** a program to execute. When no program is provided, it will open a shell and keep it open until we explicitly exit it. In the equipped environment, we can now check if the commands are available by, for example, requesting their version:

```bash
avr-gcc --version
```

In this shell, we can now compile our source code. We use the same code and configuration as we [used before][3]. We can build it by executing the following commands in the provided shell:

```bash
meson setup --cross-file ./avr-atmega328p.txt --buildtype debug ./build
meson compile -C ./build
```

> I will not go into detail about the code, the build system, or the commands for the build and flashing. You can look into the previous [post][3] to learn more about it. If you only want to look at the code, it is available on [codeberg][12].
{: .prompt-info }

After these commands, we can now flash the Arduino board with the following:

```bash
avrdude -p atmega328p -c arduino -P /dev/ttyACM0 -b 115200 -U flash:w:./build/atmega328p/release/blinky.hex:i
```

### Creating a manifest

With all commands executed, we can ensure that our shell has everything we need to build and flash our software. All these tools are now only available in this shell. After we close it, they will not interfere with other toolchains on our systems. 

Determining which programs we need every time we return to this project would take time and effort. [GNU Guix][1] provides a mechanism to simplify this process: *manifest files*. A *manifest* in this sense, is some package list or *bill of material* if you want. This file is supported by most of the [GNU Guix][1] commands. Let us create one for our shell:

```bash
guix shell gcc-cross-avr-toolchain meson ninja avrdude --export-manifest > manifest.scm
```

The first part of this command is our shell with the list of programs we use and the parameter `--export-manifest`. This parameter prints out the *manifest* content for our configuration. In the second part (`> manifest.scm`) we write this content to the file `manifest.scm`. The file content should look like this:

```scheme
(specifications->manifest
  (list "gcc-cross-avr-toolchain"
        "meson"
        "ninja"
        "avrdude"))
```

The content is a simple scheme function with a list of our packages. If we now want to open our shell again, we can pass the *manifest file* to [`guix shell`][2] with the `--manifest` parameter:

```bash
guix shell --manifest=manifest.scm
```

Or short as:

```bash
guix shell -m manifest.scm
```

This command brings us right back into the same shell we had before. You can shorten the command to `guix shell` if you authorize the directory. To do so, you need to add the directory to the `shell-authorized-directories` file:

```bash
echo $(pwd) >> ${HOME}/.config/guix/shell-authorized-directories
```

After you add the path to the file, you can enter `guix shell` in the directory, and this will create the shell.

### Pure environments

If we want to ensure that our shell contains everything we need, we can add the `--pure` parameter. This parameter will not allow us to propagate our profile within the shell. The command to build our code in a *pure shell* is:

```bash
guix shell -m manifest.scm --pure -- meson compile -C ./build
```

> [GNU Guix][1] takes the `--pure` parameter serious. This means (at least on Guix System) you will **only** have what you have defined, so also the [GNU Coreutils](https://www.gnu.org/software/coreutils/) are **not available**. To get the best experience with *pure shells* you should directly execute the commands and not switch into the shell.
{: .prompt-warning }

A *pure shell* will still consider configurations in your home directory. If you want to have it even more isolated, you can run your environment also containerized:

```bash
guix shell --container -m manifest.scm
```

[Guix Containers][13] are very lightweight. They use [Linux namespaces][14] under the hood to provide process isolation. Containers allow you to define precisely which resources should be available in your environment. By default, you have only your shell environment and current directory. If you need additional resources, you can use `--share` to provide them to your container. So, if you want to flash an Arduino from a container, you can do this by sharing the device:

```bash
guix shell --container -m manifest.scm --share=/dev/ttyACM0=/dev/ttyACM0 -- \
  avrdude -p atmega328p -c arduino -P /dev/ttyACM0 -b 115200 -U flash:w:./build/atmega328p/release/blinky.hex:i
```

### Reproduce the environment

We have defined our environment, but how can we ensure we always get the same? One of the main benefits of [GNU Guix][1] is reproducibility. We can use [GNU Guix][1] to ensure that we will get the same environment we currently use in a few months or years, not only on this machine but also on each system that invokes Guix commands.

To enable this, we need to ensure we can return to the same definition of our packages again. We need to provide the version (commit hash) from our packages. [GNU Guix][1] allows you to invoke [`guix describe`][15] to archive exactly that:

```bash
guix describe -f channels > .guix-channels-lock.scm
```

This command describes your current channels as a scheme list and writes this to a file called `.guix-channels-lock.scm`. The content of the file looks like this:

```scheme
(list (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")
        (branch "master")
        (commit
          "bc6840316c665e5959469e5c857819142cc4a47b")
        (introduction
          (make-channel-introduction
            "9edb3f66fd807b096b48283debdcddccfea34bad"
            (openpgp-fingerprint
              "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
```

This list contains all channels you have currently defined in your profile with their current git hash. If this includes channels you do not need for your development environment, you can delete them from the file. This file enables *time travel* with [`guix time-machine`][16].

The [`guix time-machine`][16] command allows us to access other revisions of [GNU Guix][1] and the packages defined in this specific revision of [GNU Guix][1]. So, if we want to create the same shell again, we can use this command:

```bash
guix time-machine --channels=./.guix-channels-lock.scm -- shell -m manifest.scm
```

This command will at first provide [GNU Guix][1] and all channels inside of `.guix-channels-lock.scm` in the specified version and then invoke everything provided after `--` to this version of [GNU Guix][1]. So it rolls back [GNU Guix][1] and then invokes `guix shell` on the specified version.

> Running [`guix time-machine`][16] the first time for a channel could take quite a bit of time. This command will create precisely the specified [GNU Guix][1] version, starting from the bootstrap. So, the commands will behave exactly like they did at this point in time. It would also allow you to execute commands that exist at this point but are already removed in later versions.
{: .prompt-info }

This combination of [`guix shell`][2], [`guix describe`][15], and [`guix time-machine`][16] allows us and everybody we give access to the files, to create the same environment we used, when we started the project. If we have our `manifest.scm` and our `.guix-channels-lock.scm` in a version control system, together with our code, we can ensure that we can **build every commit** of the source code **at any point in time**.

## Docker vs. `guix shell`

In the last [post][3], I explained how to set up a development environment with [Docker][7], and this time, I did the same with [`guix shell`][2]. So what is the benefit of one over the other?

Both provide a way to stabilize and exchange development environments over different systems. Both do a great job here; however, the main difference for me is the user experience. My main problem with [Docker][7] is the *"docker experience"*. If I switch into a shell in a docker container, it feels alien. It feels like I would connect to a different machine, and my typical tooling is unavailable. Setting up a language server or debugging from a container is an additional effort within my regular tooling. In a [`guix shell`][2], on the other side, it behaves like my normal system; all aliases are there, all tools are available, and it connects to my development environment like every other tool or library on the system.

Also, if you want to add a tool or dependency in a [`guix shell`][2], you can add it to the command, and if you need it for future shells, add it in the `manifest` file. Long rebuilding of the layers is not required. You also do not need to care about the container size; caching in the guix store removes much of the burden.

Because of this, I mostly use [`guix shell`][2] this day. I use [Docker][7] only with old or external toolchains. I am also writing this blog post with [`guix shell`][2]. [Jekyll](https://jekyllrb.com/), the static website generator I use for this blog, runs in a guix shell with the defined ruby version and gems I need.

### Create docker images

[Docker][7] still has benefits over [`guix shell`][2]. The main one is that it has been established and used in the industry for years. A lot of CI/CD tooling is powered by [Docker][7]. Changing this all at once would be a tremendous amount of effort. Gladly, this is not necessary. [GNU Guix][1] allows you to create a docker image from your environment.

The command [`guix pack`][17] allows you to create a docker image with a given set of packages. We can use our `manifest.scm` to build our image by executing:

```bash
guix pack -f docker -m manifest.scm
```

This command creates a docker image and packs it as a tarball inside the `/gnu/store` directory. If you want to ensure the version, you can also combine it with [`guix time-machine`][16]:

```bash
guix time-machine --channels=./.guix-channels-lock.scm -- pack -f docker -m manifest.scm
```

This command creates the file `/gnu/store/rsfr2gr0y5hch4qvh05l4ayym3xj1cp1-gcc-cross-avr-toolchain-meson-ninja-docker-pack.tar.gz`. You can then load this tarball into [Docker][7] by executing:

```bash
docker load < /gnu/store/rsfr2gr0y5hch4qvh05l4ayym3xj1cp1-gcc-cross-avr-toolchain-meson-ninja-docker-pack.tar.gz
```

After the command, the image is available for [Docker][7]. You can then work with it like you would with every other image. You can run, rename or publish the image like it was created from a `Dockerfile`. If you want, for example, to rename the image to a more useful name, you can do it like this:

```bash
docker image tag localhost/gcc-cross-avr-toolchain-meson-ninja:latest avr-toolchain:latest
```

This way, you can still use docker tooling but provide the images with [GNU Guix][7] to combine the best of both worlds.

> The command [`guix pack`][17] provides also a lot of other useful format options. For example, if you want to send your programs to a college, you can invoke `guix pack -f tarball -RR -m manifest.scm`. This command will create a tarball with *relocatable binaries*, which allows them to run on nearly every GNU/Linux system.
{: .prompt-tip }

## Summary

In this post, we reviewed the basics of [`guix shell`][2] and created a development environment for AVR with this command. [`guix shell`][2] allows the creation of an environment that interacts perfectly with the overall system but also allows isolation if needed. We also enabled with [`guix describe`][15] the [`guix time-machine`][17] command to ensure reproducibility. In the end, we compared [`guix shell`][2] with [Docker][7] and created docker images by invoking [`guix pack`][17].

This post described only the tip of the iceberg about the possibilities [`guix shell`][2] provides. Creating the firmware in various configurations directly with [`guix shell`][2] and [`guix build`][18] or deploying the compiled source code with [GNU Guix][1] is also possible. We can also combine [`guix shell`][2] with tools like [just](https://just.systems/man/en/) to create an even better experience for the development.

## References

* GNU Guix Reference Manual: [Invoking `guix shell`][2]
* GNU Guix Reference Manual: [Writing Manifests](https://guix.gnu.org/en/manual/devel/en/html_node/Writing-Manifests.html)
* GNU Guix Reference Manual: [Invoking `guix describe`][15]
* GNU Guix Reference Manual: [Invoking `guix time-machine`][16]
* GNU Guix Reference Manual: [Invoking `guix pack`][17]

## Footnotes
[^1]: It also provides [AVRDUDE][11], but I prefere to have it explicit installed.

[1]: https://guix.gnu.org/
[2]: https://guix.gnu.org/manual/devel/en/html_node/Invoking-guix-shell.html
[3]: {% post_url 2023-10-31-arduino-setup%}
[4]: https://guix.gnu.org/manual/en/html_node/Invoking-guix-gc.html
[5]: https://www.gnu.org/software/hello/
[6]: https://octave.org/index
[7]: https://www.docker.com/
[9]: https://mesonbuild.com/
[10]: https://ninja-build.org/
[11]: https://github.com/avrdudes/avrdude
[12]: https://codeberg.org/zie87/guix-samples/src/branch/main/shells/avr/blinky
[13]: https://guix.gnu.org/en/cookbook/en/html_node/Guix-Containers.html
[14]: https://en.wikipedia.org/wiki/Linux_namespaces
[15]: https://guix.gnu.org/manual/en/html_node/Invoking-guix-describe.html
[16]: https://guix.gnu.org/manual/en/html_node/Invoking-guix-time_002dmachine.html
[17]: https://guix.gnu.org/manual/en/html_node/Invoking-guix-pack.html
[18]: https://guix.gnu.org/manual/en/html_node/Invoking-guix-build.html
