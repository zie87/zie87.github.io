---
layout: 'post'
title: 'GNU Guix: How to run foreign binaries'
date: '2024-05-20 13:15:00'
categories: ['Guix' ]
tags: ['guix', 'gnu', 'linux', 'functional', 'scheme', 'guile', 'rust', 'nonguix', 'container', 'factorio']
---

In the last weeks, I wanted to try out some of [Rust][3] applications. Normally when I want to try out programs in [Guix][1] I simple install it directly or [create a package][2] for it. But not for programs written in [Rust][3]. The [Rust][1] ecosystem makes it very easy to reuse code and developers use this excessively. Because of this, packaging such programs is no fun at all.

Today a lot of programs provide prebuilt binaries. I wanted to use those to avoid to deal with the dependencies. But this is not as simple under [Guix][1] like it is for other distros.

## What's the problem?

At first the general problem with third party binaries:

> Running third party binaries can (potentially) harm your system. You should only use binaries from trusted source.
{: .prompt-danger }

Beyond this obvious issue [Guix][1] does not apply to the [Filesystem Hierarchy Standard (FHS)][4], so most prebuilt binaries are not able to find there dependencies. Let us take the file manager [yazi][7] as an example. The project provides two binaries for each release. One build against the [GNU C Library][8] and one (fully static) build against [musl libc][9]. The *musl-build* will run out of the box, but if we try to run the *gnu-build* we are faced with this error:

```bash
./yazi-x86_64-unknown-linux-gnu/yazi 
bash: ./yazi-x86_64-unknown-linux-gnu/yazi: No such file or directory
```

This error message is a bit missleading. What it tries to say is *elf interpreter not found*. Most [ELF][6] files assume the location of the dynamic loader (*ELF Interpreter*). The interpreter it searches for is `ld-linux.so` and normally found under `/lib`, `/lib64` or `/usr/lib`, but not so in [Guix][1]. Additionally most programs are linked against (multiple) shared objects on the system. This libraries can also create issues if the are not provided by the `LD_LIBRARY_PATH`.

Now we see the issue how can we solve it?

## Patch the binaries with `patch-elf`

One way to resolve the issue is with a small util called [`patchelf`][10]. This tool allows us to modify the dynamic linker and `RPATH` of an ELF executable. This tool allows us to verify and fix our issue.

The tool allows us to print the expected *ELF interpreter* with the command `patch-elf --print-interpreter`. We can install the program with `guix install patchelf` and then run:

```bash
guix shell patchelf -- patchelf --print-interpreter ./yazi-x86_64-unknown-linux-gnu/yazi
/lib64/ld-linux-x86-64.so.2
```

This shows us that the path for `ld-linux` is wrong. We can now use the same tool to fix this issue with:

```bash
patchelf --set-interpreter "$(patchelf --print-interpreter "$(realpath "$(which sh)")")" yazi-x86_64-unknown-linux-gnu/yazi
```

This command sets the interpreter to the same *ELF interpreter* as `sh`. Now we can verify the interpreter again to verify the fix:

```bash
patchelf --print-interpreter yazi-x86_64-unknown-linux-gnu/yazi
/gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/ld-linux-x86-64.so.2
```

This shows us now the path in the guix store and if we run it the error changes:

```bash
./yazi-x86_64-unknown-linux-gnu/yazi
./yazi-x86_64-unknown-linux-gnu/yazi: error while loading shared libraries: libgcc_s.so.1: cannot open shared object file: No such file or directory
```

Now we run in the issue of missing shared objects. We can see the needed libraries by using the `ldd` command provided by the `gcc-toolchain` package:

```bash
guix shell gcc-toolchain -- ldd ./yazi-x86_64-unknown-linux-gnu/yazi
        linux-vdso.so.1 (0x00007ffef914e000)
        libgcc_s.so.1 => not found
        libm.so.6 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/libm.so.6 (0x00007fb831c43000)
        libc.so.6 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/libc.so.6 (0x00007fb830a04000)
        /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/ld-linux-x86-64.so.2 (0x00007fb831d22000)
```

This shows we only miss `libgcc_s.so`, this library is provided by `gcc-toolchain` so we only need to install it and set the `LD_LIBRARY_PATH` to execute [`yazi`][7]:

```bash
LD_LIBRARY_PATH=$LIBRARY_PATH ./yazi-x86_64-unknown-linux-gnu/yazi
```

We can also set the `rpath` for the library with `patchelf`. For this we need at first find the location of the missing library:

```bash
guix locate -u libgcc_s.so
gcc-toolchain@13.3.0 /gnu/store/y11hlxawl23iz2jja9c3rqzc7gvfbgxx-gcc-toolchain-13.3.0/lib/libgcc_s.so
```

Now we can also adjust the the `rpath` by executing:

```bash
patchelf --set-rpath /gnu/store/y11hlxawl23iz2jja9c3rqzc7gvfbgxx-gcc-toolchain-13.3.0/lib ./yazi-x86_64-unknown-linux-gnu/yazi
```

If we now run `ldd` again we see that each library is found and we are able to run [`yazi`][7] directly:

```bash
guix shell gcc-toolchain -- ldd ./yazi-x86_64-unknown-linux-gnu/yazi
        linux-vdso.so.1 (0x00007ffe75427000)
        libgcc_s.so.1 => /gnu/store/y11hlxawl23iz2jja9c3rqzc7gvfbgxx-gcc-toolchain-13.3.0/lib/libgcc_s.so.1 (0x00007f1f59c2c000)
        libm.so.6 => /gnu/store/y11hlxawl23iz2jja9c3rqzc7gvfbgxx-gcc-toolchain-13.3.0/lib/libm.so.6 (0x00007f1f59b4f000)
        libc.so.6 => /gnu/store/y11hlxawl23iz2jja9c3rqzc7gvfbgxx-gcc-toolchain-13.3.0/lib/libc.so.6 (0x00007f1f58a04000)
        /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/ld-linux-x86-64.so.2 (0x00007f1f59c53000)
```

We can now run our foreign binary, but this is not confinient. It is a lot of work before the first run and we need to repeat the process as soon as we update the dependencies in our profile. Let us try a better way be using [`guix shell`][11].

## Isolation with `guix shell`

### Run cli applications

We can also use [`guix shell`][11] to run our binary without patching. We can enable [FHS][4] emulation if we create a container with [`guix shell`][11]. Todo so we only need to add the `--emulate-fhs` (short `-F`) parameter to the shell execution. Let us see how this looks for `yazi`:

```bash
guix shell --container --emulate-fhs gcc-toolchain -- ./yazi-x86_64-unknown-linux-gnu/yazi
```

This command creates a container with `gcc-toolchain` installed, which emulates [FHS][4] and executes `yazi` directly. On top of it we are a little bit isolated from the rest of our system. If we use `yazi` we can easily navigate in our current directory but do not see anything outside of it. [Guix][1] provides all create containers be default access to the current working directory. If we want to provide more to the container we need to explicitly *expose* or *share* it with the container. So if we want to navigate with `yazi` in our complete home directory we can change the command to:

```bash
guix shell --container --emulate-fhs --share=$HOME gcc-toolchain -- ./yazi-x86_64-unknown-linux-gnu/yazi
```

The `--share` parameter maps a file or directory with read and write access in the container. If we only need read access we can use the `--expose` parameter instead.

> Guix containers use [linux namespaces](https://en.wikipedia.org/wiki/Linux_namespaces) for process isolation, this works similar to tools like [Bubblewrap (`bwrap`)][5]. 
{: .prompt-info }

### Run graphical applications

The containers are not limited to run only small cli applications. Some days ago I read a post about the [linux port of factorio](https://factorio.com/blog/post/fff-408), after this I had th urge to try the game. The game is proprietary software and in this day and age I prefere to run such software isolated, which makes guix containers perfect for the task. The simple command for `yazi` will not cut it for [factorio][12]. The game has way more dependencies and needs to have access to some system resources like display and audio. At first let us look into the dependencies:

```bash
guix shell gcc-toolchain -- ldd bin/x64/factorio 
        linux-vdso.so.1 (0x00007ffd5d2d7000)
        libdl.so.2 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/libdl.so.2 (0x00007fd2f3459000)
        librt.so.1 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/librt.so.1 (0x00007fd2f3454000)
        libresolv.so.2 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/libresolv.so.2 (0x00007fd2f3441000)
        libX11.so.6 => not found
        libXext.so.6 => not found
        libGL.so.1 => not found
        libXinerama.so.1 => not found
        libXrandr.so.2 => not found
        libXcursor.so.1 => not found
        libasound.so.2 => not found
        libpulse.so.0 => not found
        libpulse-simple.so.0 => not found
        libm.so.6 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/libm.so.6 (0x00007fd2f3360000)
        libpthread.so.0 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/libpthread.so.0 (0x00007fd2f335b000)
        libc.so.6 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/libc.so.6 (0x00007fd2f315f000)
        /lib64/ld-linux-x86-64.so.2 => /gnu/store/ln6hxqjvz6m9gdd9s97pivlqck7hzs99-glibc-2.35/lib/ld-linux-x86-64.so.2 (0x00007fd2f3460000)
```

This shows us that we need a bunch of *X11* related libraries namely: `libx11`, `libxext`, `libxinerama`, `libxrandr` and `libxcursor`. We also need the `mesa` package to solve the dependency to `libGL`. The last dependencies are audio related `libasound` is part of the `alsa-lib` package and both pulse libraries are provide via the package `pulseaudio`.

We can try to run it with only the dependencies provided by calling:

```bash
guix shell --container --emulate-fhs libxinerama libx11 libxext libxrandr mesa libxcursor alsa-lib pulseaudio -- ./bin/x64/factorio
```

This will instantly crash, because [SDL](https://www.libsdl.org/) does not find a video device, but at least we know now that we have all dependencies together. We can save the dependencies to a `manifest.scm` to reduce the typing in the future:

```bash
guix shell --container --emulate-fhs libxinerama libx11 libxext libxrandr mesa libxcursor alsa-lib pulseaudio --export-manifest > manifest.scm
```

We can now use the `manifest.scm` file to start our game. Let us at first look at the command and then see what the flags mean:

```bash
guix shell --container --emulate-fhs \
    --preserve='^XDG_|^WAYLAND_DISPLAY$' --preserve='^DISPLAY$' \
    --expose=/dev/dri \
    --share=/tmp/.X11-unix/ \
    --expose=/run/user/$UID \
    -m manifest.scm \
    -- ./bin/x64/factorio
```

At first we *preserve* some environment variables; `--preserve='^XDG_|^WAYLAND_DISPLAY$'` provides some [Wayland](https://wayland.freedesktop.org/) specific variables to the container and `--preserve='^DISPLAY$'` tells the system which display to use. We then expose `/dev/dri` to the container to enable hardware acceleration. The game use by default the X11 mode so we need to *share* the X11 resource with `--share=/tmp/.X11-unix/`. This is enough to start the game, but we will not have sound. To enable sound we need to *expose* the user resources for pulseaudio with `--expose=/run/user/$UID`. And now we can enjoy the game.

With the use of containers we have now no need for patching anymore, get rid of the hustle to repeat the patching if dependency changes and on top of that we win a little more isolation for the foreign binary. The only hustle left is the command itself. It is sometimes a lot of try and error to figure out what is needed and then we need to remember it everytime we want to run our application. But beyond this downside this is currently my go to methode for running foreign binaries.

> It is also possible to provide containers as packages. The [Guix Gaming Channel](https://gitlab.com/guix-gaming-channels/games) provides for example [factorio packages](https://gitlab.com/guix-gaming-channels/games/-/blob/master/games/packages/factorio.scm?ref_type=heads) this way.
{: .prompt-tip }

## Package binaries

Sometimes you want to have a excutable integrated into the system, but you are still not convinced it is worth the hustle to setup the build from source. If this is the case you can use the [binary buildsystem](https://gitlab.com/nonguix/nonguix/-/blob/master/nonguix/build-system/binary.scm?ref_type=heads) from [nonguix](https://gitlab.com/nonguix/nonguix). This buildsystem makes it easy to patch and package a foreign binary. The package for `yazi` for example looks like [this](https://codeberg.org/zie87/guix-config/src/branch/main/guix/zie/packages/rust-bin.scm):

```scheme
(define-public yazi-bin
  (package
    (name "yazi-bin")
    (version "0.2.5")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/sxyazi/yazi/releases/download/v" version
             "/yazi-x86_64-unknown-linux-gnu.zip"))
       (file-name (string-append "yazi-" version ".zip"))
       (sha256
        (base32 "09mdfrlwx86k8fymxjjnxilxhwfp0g9vx452ybkqc8y4mjls2wxn"))))
    (build-system binary-build-system)
    (arguments
     `(#:phases (modify-phases %standard-phases
                  (add-before 'patchelf 'patchelf-writable
                    (lambda _
                      (for-each make-file-writable
                                '("ya" "yazi"))))
                  (add-after 'install 'install-completions
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((share (string-append (assoc-ref outputs "out")
                                                   "/share"))
                             (bash (string-append share
                                    "/bash-completion/completions"))
                             (zsh (string-append share
                                                 "/zsh/vendor_completions")))
                        (mkdir-p bash)
                        (mkdir-p zsh)
                        (copy-file "completions/ya.bash"
                                   (string-append bash "/ya"))
                        (copy-file "completions/yazi.bash"
                                   (string-append bash "/yazi"))
                        (copy-file "completions/_ya"
                                   (string-append zsh "/_ya"))
                        (copy-file "completions/_yazi"
                                   (string-append zsh "/_yazi"))))))
       #:patchelf-plan `(("ya" ("gcc:lib" "glibc"))
                         ("yazi" ("gcc:lib" "glibc")))
       #:install-plan `(("ya" "bin/")
                        ("yazi" "bin/"))))
    (native-inputs (list unzip))
    (inputs `(("gcc:lib" ,gcc "lib")
              ("glibc" ,glibc)))
    (supported-systems '("x86_64-linux"))
    (synopsis
     "Blazing fast terminal file manager written in Rust, based on async I/O")
    (description
     "Yazi is a terminal file manager written in Rust, based on non-blocking async I/O. It aims to provide an efficient, user-friendly, and customizable file management experience.")
    (home-page "https://yazi-rs.github.io/")
    (license license:expat)))
```

Most of this package definition is standard for [guix packages](https://guix.gnu.org/en/manual/devel/en/html_node/Defining-Packages.html). I will only focus on the intressting parts for this context. The first intressting line is `(build-system binary-build-system)` this function orders [Guix][1] to use the binary buildsystem provided bei the module `use-module (nonguix build-system binary)`. The next step is the preparation for the patching of the executable together with the `patchelf-plan`. We have two executables we need to patch: `yazi` and `ya`. To allow the patching we need to make the files writeable. We do this with:

```scheme
(add-before 'patchelf 'patchelf-writable
  (lambda _
    (for-each make-file-writable
              '("ya" "yazi"))))
```

This adds a new build phase to the binary buildsystem before the `patchelf` phase. In this phase (called `ipatchelf-writable`) we simple call the `make-file-writable` function for each of our binaries. The only missing step is to define the `patchelf-plan` this is done with:

```scheme
#:patchelf-plan `(("ya" ("gcc:lib" "glibc"))
                  ("yazi" ("gcc:lib" "glibc")))
```

This plan will patch `yazi` and `ya` with the rpath of `libgcc_a.so` (`gcc:lib`) and for the `glibc` to be sure. And then we are already done. We can now install it like every other package.

## A note about packaging Rust apps

In the intro of this post I spoke about the hustle of packaging rust applications. I think I should describe a bit more what it means to package a [Rust][3] app for [Guix][1].

Building [Rust][3] package is done in [Guix][1] via the [cargo buildsystem](https://guix.gnu.org/en/manual/devel/en/html_node/Build-Systems.html). Each dependency of the application needs to be defined as an own package which can than be used for `cargo-inputs`. [Guix][1] provides also an [importer](https://guix.gnu.org/manual/en/html_node/Invoking-guix-import.html) to create the package definitions based on the [crates.io registry](https://crates.io/).

So if we want to create a package for `yazi` we simply need to run:

```bash
guix import crate -r yazi-fm > yazi.scm
```

> Check the [crates.io registry](https://crates.io/) for the right package name. In this case the package is called `yazi-fm` not `yazi`.
{: .prompt-info }

This command will generate a package definition for `yazi` and all its dependencies in a file called `yazi.scm`. The created file is over 4500 lines long, defines over 170 different packages and is incomplete. The importer is not perfect and needs some manual adjustments. We need to define the needed modules and fix some packages because of errors in the license detection. After this fixes we can try to build it with:

```bash
guix build -f yazi.scm
```

And then we run in build errors we need to fix. This errors are build errors because of missing or wrong system dependencies, missing build options for dependencies and so on. I stopped here but also if we would be able to build the package we should recheck all licenses of the packages. Sometime the licenses from [crates.io](https://crates.io/) do not match the licenses on the project pages.

> Currently there is some work ongoing to simplify the build of [Rust][3] apps for [Guix][1]. The idea is to utilize the `Cargo.lock` file for the dependency management. ([mail thread](https://lists.gnu.org/archive/html/guix-devel/2024-05/msg00166.html))
{: .prompt-info }

So this cli application would create us quite an effort to packages it and afterwards we will have over 100 packages we need to maintain. Also some of the dependencies look sketchy, they are not maintained for a while do not provide proper license informations or a setup in way which gives me an uncanny feel. Overall we are deep in an issue with the [Rust][3] ecosystem: **trust**. You need to trust in all the dependecies that they are free from serious issues and will not bring your system in any danger and that none of the dependencies is compromissed. All this brings me currently in the situation, that I'm very cautious about [Rust][1] apps.

## Summary

In this blog post we looked at some possiblities to use foreign binaries in a [Guix][1] system. We can patch a binary with [patchelf][10] to make it executable with the dependencies inside the *store*. We also can create an [FHS][4] compatible container with [`guix shell`][11] to not only run the binary but also provide an isolated environment. At the end we also looked how we can use the [binary buildsystem](https://gitlab.com/nonguix/nonguix/-/blob/master/nonguix/build-system/binary.scm?ref_type=heads) from [nonguix](https://gitlab.com/nonguix/nonguix) and made some notes about how to package a [Rust][3] app.

## References

* GNU Guix Reference Manual: [Invoking `guix shell`][11]
* GNU Guix Reference Manual: [Writing Manifests](https://guix.gnu.org/en/manual/devel/en/html_node/Writing-Manifests.html)
* GNU Guix Cookbook: [Guix Containers](https://guix.gnu.org/en/cookbook/en/html_node/Guix-Containers.html)

[1]: https://guix.gnu.org/
[2]: https://guix.gnu.org/en/manual/devel/en/guix.html#Defining-Packages
[3]: https://www.rust-lang.org/
[4]: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
[5]: https://github.com/containers/bubblewrap
[6]: https://en.wikipedia.org/wiki/Executable_and_Linkable_Format
[7]: https://github.com/sxyazi/yazi
[8]: https://www.gnu.org/software/libc/
[9]: https://musl.libc.org/
[10]: https://github.com/NixOS/patchelf
[11]: https://guix.gnu.org/en/manual/devel/en/guix.html#Invoking-guix-shell
[12]: https://factorio.com/
