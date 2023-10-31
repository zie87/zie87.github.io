---
layout: 'post'
title: 'Baremetal Arduino: Setting up a development enviroment'
date: '2023-10-31 13:00:00'
categories: ['Embedded', 'Baremetal Arduino']
tags: ['arduino', 'arduino uno', 'arduino nano', 'arduino mega', 'atmel', 'embedded', 'meson', 'docker']
---

I decided to play around with my [Arduino][1] boards again, and this is an excellent opportunity to explain how to set up a development environment for cross-compilations. For this project, we need to set up some tools. The tools I decided to use are the avr-toolchain, including [AVRDUDE][6], [Docker][3] to set up the toolchain, and [Meson][2] as the build system. We will mainly focus on the [Arduino][1] boards, which use Atmels ATmega328p Microcontroller. These boards are, for example, the Arduino Uno and the Arduino Nano.

[Meson][2]
: [Meson][2] is a build system I quite enjoy. It keeps the build configuration simple and easy to understand and also makes it easy to set up cross-compilation.

[Docker][3]
: Allows application deployment via containerization. [Docker][3] makes it easy to define the toolchain once and reuse it on different systems or for [CI/CD](https://en.wikipedia.org/wiki/CI/CD).

[AVRDUDE][6]
: A versatile tool to program Atmel AVR microcontrollers. The Arduino IDE also uses it and provides the necessary configurations for most of the [Arduino][1] boards.

## Setup the Toolchain with Docker

We will set up the environment with our toolchain via [Docker][3]. [Docker][3] allows us to handle our environment with a single file and makes it easy to reproduce it on multiple machines. For our current use case, we need to create a file called [`Dockerfile`][7] with this content:

```docker
FROM alpine:3.18

RUN apk --no-cache add ca-certificates bash wget git make \
  meson ninja-build \
  avr-libc gcc-avr \
  avrdude

WORKDIR /workdir
```

The first line, `FROM alpine:3.18`, defines our base image. We use [Alpine Linux][4] as our base. [Alpine][4] is a small distribution that already provides everything we need in its package repository.

The `RUN` instruction is the heart of this file. This instruction runs the [Alpine][4] package manager `apk` and installs the needed software. For this project, we need the packages `meson` and `ninja-build` to provide our build system. The packages `gcc-avr` and `avr-libc` provide us with the compiler and the necessary libraries, and `avrdude` installs the programmer we will use. The other packages are installed for convenience. I like to work directly in the container. For this, we need `bash`. The packages `wget`, `git`, and `make` are required for [Meson Subprojects](https://mesonbuild.com/Subprojects.html), which will not used in this blog post.

The last instruction is `WORKDIR`. This instruction sets and creates the working directory for the container. The entry points of the container use this directory.

The next step is to create an image out of our [Dockerfile][7]. We can do this by calling:

```sh
docker build -t zie87/avr-toolchain .
```

The argument `-t` gives our image a name that can be chosen freely. In this case, the name for the image is `zie87/avr-toolchain`. With the command `docker images`, we can check if the image is available. After the build step, we can switch to a bash shell in our container with the following command:

```
docker run --rm --init --device "/dev/ttyACM0:/dev/ttyACM0" -v $PWD:/workdir:Z -e LANG=$LANG -it zie87/avr-toolchain /bin/bash
```

The command `docker run` runs the container and starts bash for use inside it. The meaning of the parameters are:

`--rm`
: Removes the container if it already exists

`--init`
: This flag tells Docker to use an init process as PID 1 inside the container. It allows to handle signal propagation and zombie processes correctly.

`--device "/dev/ttyACM0:/dev/ttyACM0"`
: This option allows us to pass through a device from our host machine into the container. Devices are later needed to allow [AVRDUDE][6] access to the [Arduino][1] boards from our container.

`-v $PWD:/workdir:Z`
: This option mounts our current directory as a volume to the container with `\workdir` as the mount point. The `:Z` option allows us to write directly to this mount point.

`-e LANG=$LANG`
: This option sets the LANG environment variable to the value of the LANG variable from your host system. It can avoid some issues when we work inside the container. 

`-it`
: These flags are used to start an interactive session within the container. It opens a terminal and allows us to interact with the shell.

`zie87/avr-toolchain`
: This is the name of the Docker image we want to run.

`/bin/bash`
: The last argument is the command we want to run inside the container. In this case, it starts a Bash shell, and together with the `-it` argument, we now have an interactive shell in the container.


We can also run our container in a *detached mode*. To do so, we need to add the flag `-d` additionally and remove the call of the bash interpreter. The command would look like this:

```sh
docker run -d --rm -it --init --device "/dev/ttyACM0:/dev/ttyACM0" -v $PWD:/workdir:Z -e LANG=$LANG zie87/avr-toolchain
```

With `docker ps`, we can now see our container. The output can look like this:

```sh
$ docker ps
CONTAINER ID   IMAGE                 COMMAND                  CREATED         STATUS         PORTS     NAMES
63c5437ec73b   zie87/avr-toolchain   "/bin/sh"                2 minutes ago   Up 2 minutes             cranky_haibt
```

The name (`cranky_haibt`) is chosen by the docker engine. To define a different name, we must add the name with the `--name` flag to the run command. With the container detached, we can directly send commands to it with `docker exec`:

```sh
docker exec cranky_haibt ls -la
```

The command will list all files in the current directory of the container. With `docker exec`, we can run our build commands 
and scripts in the container without having to call `docker run` every time again. If we want to stop the detached container, we can do so with the following:

```sh
docker stop cranky_haibt
```

## Basic build configuration 

Meson already ships a tool that will provide us with a basic setup. We can use this tool by calling the `meson init` command:

```sh
meson init --name blinky --language c --build --builddir build/atmega328p
```

The arguments have the following meanings:

`--name blinky`
: Defines **blinky** as the name of the project and the executable.

`--language c`
: Sets **C** as the programming language for the project

`--build`
: Triggers a build directly after the generation

`--builddir build/atmega328p`
: Sets the directory **build/atmega328p** for the build 

The command mainly creates two files: `blinky.c` and `meson.build`. The file `meson.build` is our main build system configuration, and `blinky. c` is a **C** example. Both could be more useful for our use case, so we must replace/adapt them. Let's start with `blinky. c`. We replace the content of the file with a simple blinky implementation: 

```c
#include <avr/io.h> // Contains I/O Register definitions
#include <util/delay.h>

#define MS_DELAY 1000

int main(void) {
  DDRB |= _BV(DDB5); // Configuring PB5 as Output

  while (1) {
    PORTB |= _BV(PORTB5); // Writing HIGH to PB5
    _delay_ms(MS_DELAY);
    PORTB &= ~_BV(PORTB5); // Writing LOW to PB5
    _delay_ms(MS_DELAY);
  }
}
```

This code will switch the internal LED of an [Arduino][1] UNO/Nano each second. The next thing we need to change is the `meson.build` file. Currently, the file should look like this: 

```meson
project('blinky', 'c',
  version : '0.1',
  default_options : ['warning_level=3'])

exe = executable('blinky', 'blinky.c',
  install : true)

test('basic', exe)
```

We need to adapt this configuration for our cross-build. The project definition is fine for now. We can delete the test definition, and we need to make some changes to the definition of our executable:

```meson
exe = executable(
    'blinky',
    sources: ['blinky.c'],
    c_args: ['-DF_CPU=16000000UL'],
    name_suffix: 'elf',
)
```

The first change explicitly defines the `sources` parameter. For now, this is more of a cosmetic change. More important is the line `c_args: ['-DF_CPU=16000000UL']`. This argument defines the clock frequency (16 MHz) to our build, which the AVR libraries must provide, e.g., the `_delay_ms` function. The last change is to define the file extension with: `name_suffix: 'elf'`. We need to manipulate the executable later to flash it to our device. For this, we need to be able to distinguish the different files by extension. 

## Enable the cross-compilation

Meson supports [cross compilation](https://mesonbuild.com/Cross-compilation.html) through a cross-build definition file. This file allows us to set up the environment for our cross-toolchain. This file is structured in different [sections](https://mesonbuild.com/Machine-files.html#sections). The first section, which is vital for us, is called: `[binaries]`. This section defines programs that will be used internally by [Meson][2], like the compiler, or which need to be available for the `find_program` function. In our case, this section looks like this: 

```meson
[constants]
prefix = 'avr'

[binaries]
c           = prefix + '-gcc'
cpp         = prefix + '-g++'
ld          = prefix + '-ld'
ar          = prefix + '-ar'
as          = prefix + '-as'
size        = prefix + '-size'
objdump     = prefix + '-objdump'
objcopy     = prefix + '-objcopy'
readelf     = prefix + '-readelf'
strip       = prefix + '-strip'
```

We use the `[constants]` section to define the prefix *avr* for all our toolchain programs and then define the name of each program. Most important are, for now, the entries `c` and `strip`, which are used internally by [Meson][2] for our current build. 

The next step is configuring the compiler and the linker for our MCU via the `[built-in section]`. This section overrides the built-in defaults of [Meson][2].

```meson
[built-in options]
b_staticpic = 'false'
default_library = 'static'

c_args = [
    '-mmcu=atmega328p',
    '-ffunction-sections',
    '-fdata-sections',
    '-flto', 
    '-fno-fat-lto-objects',
    ]

c_link_args = [
    '-mmcu=atmega328p',
    '-Wl,--gc-sections',
    '-static',
    '-flto',
    '-fuse-linker-plugin',
    '-Wl,--no-warn-rwx-segment',
    '-Wl,--print-memory-usage',
    ]
```

The first option we need to override is `b_staticpic`. This variable defines if static libraries are built with position independence. The default value is `true`, which could mess up our object layout, so we must turn off this option. We do not use shared objects, so we also set the default library type to `static`.

Next are the compiler flags. We set our MCU type by adding `-mmcu=atmega328p` to the compiler flags. The flags `-ffunction-sections` and `-fdata-sections` tell the compiler to place each function and data item in its own section in the output file. This setting allows better link time optimization, which we also enable by the flag `-flto`. The last flag, "-fno-fat-lto-objects," will ensure only *slim* objects are provided, which helps with the link time. 

The last configurations we need to set are for the linker. We need to select the MCU type as we have done for the compiler. The flags `-flto` and `-fuse-linker-plugin` are required for the link time optimizations. We ensure static linkage with the `-static` flag and `--gc-sections` can reduce the executable size based on the compiler flags `-ffunction-sections` and `-fdata-sections`. The last arguments are for convenience: `--no-warn-rwx-segment` suppresses a warning about the LOAD segment permissions, which does not apply to use, and `--print-memory-usage` gives us an excellent output after the linkage about the used memory regions.  

> If you need more clarification about the proper compiler configurations, you can use the [Arduino IDE](https://docs.arduino.cc/software/ide-v2) builds as a template. If you run the build, the output shows which flags are used by the compiler and the linker.  
{: .prompt-info }

The last section we need to take care of is `[host_machine]`:

```meson
[host_machine]
system     = 'atmega328p'
cpu_family = 'avr'
cpu        = 'atmega328p'
endian     = 'little'
```

In this section, we define some information about the machine that will run our code later. Here, we give our system and CPU a name (`atmega328p`). We also define the `cpu_family` based on the [reference table](https://mesonbuild.com/Reference-tables.html#cpu-families), and we provide the information about the system's endianness.

With this in place, we can build our application for the [Arduino][1] board. To build it, we need to first configure our project with the cross-definition file we have created. We do this with `meson setup`: 

```sh
meson setup --cross-file ./avr-atmega328p.txt --reconfigure --buildtype minsize build/
```

Then, we can compile the project:

```sh
meson compile -C build
```

After this, we will find a `blinky.elf` file in the build directory. We can verify if the build is proper for our Atmel MCU with the command `file ./build/blinky.elf`. The command should show us an output like this:

```
$ file build/blinky.elf
build/blinky.elf: ELF 32-bit LSB executable, Atmel AVR 8-bit, version 1 (SYSV), statically linked, with debug_info, not stripped
```

## Programm the Arduino

We have created an [ELF-file][5], which contains all the necessary information about how the data and code must be organized. But to program it, we need to align this with the memory regions of the [Arduino][1]. For this, we need to convert the [ELF-file][5] into an HEX-file, which would reflect the memory regions of the [Arduino][1]. The tool `avr-objcopy` creates this HEX-file for us. The call of `avr-objcopy` will look like this:

```sh
avr-objcopy -O ihex -R .eeprom blinky.elf blinky.hex
```

We can integrate this step directly into our Meson build. To do so, we need to define the binary for `objcopy` in the `[binaries]` section of our cross-build definition file (*avr-atmega328p.txt*). Doing so allows us to find the program with the `find_program` function of [Meson][2]. Next, we must add the program call to our `meson.build` file. We can do this by adding the following lines to the file:

```meson
objcopy = find_program('objcopy')

custom_target(
    'blinky_hex',
    input: exe,
    output: ['blinky.hex'],
    build_by_default: true,
    command: [objcopy, '-O', 'ihex', '-R', '.eeprom', '@INPUT@', '@OUTPUT@'],
    depends: [exe]
)
```

The call of the `find_program` function gives us the `avr-objcopy` executable. We must then define a [custom build target](https://mesonbuild.com/Custom-build-targets.html) via the `custom_target` function. The first parameter (*blink_hex*) is the target's name. Next, we must define our *input* and *output*. The *input* is simply the executable target (`exe`), and the *output* is defined as `blinky.hex`. The `command` argument specifies our call to `avr-objcopy`. Here, we only provide the parameters for the call separated by ',' to the `objcopy`-program and use the defined *input* and *output* as parameters by the corresponding `@INPUT@` and `@OUTPUT@`. The last steps are to ensure it is called by the default build with: `build_by_default: true` and define that this should only run after the executable was compiled by defining the dependency: `depends: [exe]`.

Now, if we recompile the project with `meson compile -C build`, we will also find the file `blinky.hex` in the build directory. This hex file can be used by [AVRDUDE][6] to program our [Arduino][1] boards. The command to start the programming looks like this:

```sh
avrdude -p atmega328p -c arduino -P /dev/ttyUSB0 -b 115200 -U flash:w:./build/blinky.hex:i
```

Let us unpack the provided arguments:

`-p atmega328p`
: This defines the MCU, which is connected to our programmer.

`-c arduino`
: Defines the used pin configuration. This configuration is read from a configuration file, and the id `arduino` provides a predefinition for [Arduino][1] UNO/Nano boards. 

`-P /dev/ttyUSBO`
: Port where the programmer is connected to. Usually, this would be a *COM* port under Windows, and under Linux, it is `/dev/ttyUSBx` or `/dev/ttyACMx`.

`-b 115200`
: Defines the baud rate for the programmer. Mainly, 115200 baud should work, but for some cheap clones, you need to reduce the baud rate to 96000 or 57600.

`-U flash:w:./build/blinky.hex:i`
: Spezialize the memory operation in the format: `memtype:op:filepath[:format]`. The field `memtype` defines the memory type to operate on, in our case, *flash*. The operation is 'w' in our case, which will read the date from the provided file and write it to the device memory. The filepath is the path to our HEX-file (`/build/blinky.hex`), and the format value 'i' indicates that we use the Intel Hex format[^1].

## Summary

In this blog post, we set a development environment for [Arduino][1] with the use of [Meson][2], [Docker][3] and [ADRDUDE][6]. The setup of such an environment is a small amount of work, which pays off quickly. The environment we have created allows us to reproduce our builds on each system that supports docker. The build system makes it easy to compile and ensures the compilation configurations for the complete project.

## References

* [The Meson Build system][2]
* [Dockerfile reference][7]

## Footnotes

[^1]: It would also be possible to provide the [ELF-file][5] by defining the format with `e`. The call would look like this: `avrdude -p atmega328p -c arduino -P /dev/ttyACM0 -b 115200 -U flash:w:./build/blinky.elf:e`

[1]: https://www.arduino.cc/
[2]: https://mesonbuild.com/
[3]: https://www.docker.com/
[4]: https://www.alpinelinux.org/
[5]: https://en.wikipedia.org/wiki/Executable_and_Linkable_Format
[6]: https://github.com/avrdudes/avrdude
[7]: https://docs.docker.com/engine/reference/builder/
