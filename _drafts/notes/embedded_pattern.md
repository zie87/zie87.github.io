# Patterns for Embedded Programming

- [x] Michael Caisse: C++Now 2018 ["Modern C++ in Embedded Systems"](https://youtu.be/c9Xt6Me3mJ4)
  - vendor tools and dev boards reduce the TTHW (Time to "hello world")
  - How to make it work:
    - use standard tools (GCC, CMake etc.)
    - configure the libaries:
      - reset operation
      - memory layouts
      - start-up needs
      - peripherial needs
      - language needs ASM, C, C++
    - create the linker script and define it in the build system
    - create startup code (ASM, C) 
    - load to flash (write the bootloader) 
  - zero cost abstraction:
    - inline functions don´t look the code we wrote
    - const can allow the compiler to optimize LOCs away
    - static polymorphism and devirtualization inline and simplify result
    - results can change with each debug and optimization flag
  - ROOM-Ports: via compile time bindings:
    - bind ports at compile time / run time
    - compile time checks (eg.: via types)
    - policies at "controller"
    - bind ports to hardware
  - create a `C++` test to ensure the language features work on the hardware

- [x] Michael Caisse: CppCon 2021 ["Using C Libraries in your Modern C++ Embedded Project "](https://youtu.be/Ototzy-nP4M)
  - overloads: wrap into `extern "c"` functions 
  - *ideas*:
    - scratch out the code (throw away over over engineering)
    - "higher" level hardware abstraction
    - statemachine handles to main loop events

- [x] Steve Bush: CppCon 2022 ["C++ Patterns to Make Embedded Programming More Productive"](https://youtu.be/6pXhQ28FVlU) ([code](https://github.com/sgbush/cppcon2022))
  1. use functors to hide gpio operations
  1. generate lookup tables via constexpr functions
  1. use constexpr user defined literals for data creation or conversion
  1. define own streams and use the stream operator
  1. use own (area) allocators to enable `std::vector`, `std::dequeue`, etc.
  1. unlock `std::chrono` via overwriting `std::clock::now()`
  1. unlock `std::random` via writting an own random device

- [x] Dan Saks: Meeting Embedded 2018 ["Writing better embedded Software"](https://youtu.be/3VtGCPIoBfs)
  * C++ intro for embedded

- [x] Dan Saks: CppCon 2020 ["Memory-Mapped Devices as Objects"](https://youtu.be/uwzuAGtAEFk)
  * explaination how to map memory
  * volatile and placement new

- [x] Ben Saks: CppCon 2021 ["Handling a Family of Hardware Devices with a Single Implementation"](https://youtu.be/EM83l5NZ15c)
  * devices are almost always **memory-mapped**, so each device register has an address in memory space
  * *idea:* use a **memory-mapped layout** which is created based on **traits**
  * uses atmega as sample controller
  * **TODO:** try to reimplement the timers explained in the talk

  ```cpp
  using device_register = volatile std::uint32_t;

  class Uart {
  public:
    Uart();
    /*...*/
  private:
    device_register ULCON;
    device_register UCON;
    device_register USTAT;
    /*...*/
  };

  const void* uart0_addr { reinterpret_cast<void*>(0x03FFD000) };
  const void* uart1_addr { reinterpret_cast<void*>(0x03FFE000) };

  Uart& uart0 { *new(uart0_addr) Uart }; // placement new for Uart0
  Uart& uart1 { *new(uart1_addr) Uart }; // placement new for Uart1
  ```

- [x] Wouter van Ooijen: Meeting C++ 2014 ["Objects? No Thanks!"](https://youtu.be/k8sRQMx2qUw)
  * *idea*: use templates as abstraction, based on static objects with template parameters for the configuration
  * static objects: `init()` is necessary, because construction time is not defined
  * static type conversions for pins: generic pin type will be converted via template to input or output pin
  * template conversions to provide decorator functionalities
  * [Blog: Objects? No, thanks!](https://www.embedded.com/objects-no-thanks-using-c-effectively-on-small-systems/)
  * [Code: talk gpio abstraction](https://github.com/wovo/talk-gpio-abstractions/tree/master)
  * [Code: hwcpp](https://github.com/wovo/hwcpp)
  * [Code: godafoss2](https://github.com/wovo/godafoss2)
  * [Code: hwlib (OO)](https://github.com/wovo/hwlib) ([examples](https://github.com/wovo/hwlib-examples/tree/master))


- [x] Wouter van Ooijen: ACCU 2019 ["Better embedded library interfaces with modern C++"](https://youtu.be/ArRuPzN7JXs) 
  * use the right int type (signed/unsigned, fast, least)
  * template interface and cost of alternatives
  * concepts to constrain templates

- [x] Odin Holmes: CppNow 2018 ["C++ Mixins: Customization Through Compile Time Composition"](https://youtu.be/wWZi_wPyVvs)
  * mixin composition:
    - composition: object which contains a valid set of mixins
    - interface mixins: add to the public interface of the composed objects 
    - Implementation mixins: apply private implementation details

  ```cpp
  auto thing = mixin::compose(
    mixin::interface<bells, whistles>,
    guts{haggis},
    more_guts
    my_allocator{arena});

  thing.ring();
  ```

  ```cpp
  // interface mixin
  template<typename T>
  struct bells : T {
    void ring();
  };
  // anything in the public interface of the mixin will be added in the public interface of the composition
  ```

  ```cpp
  // Implementation mixin
  struct guts {};
  // non special requierements
  ```

  * abilities: combines syntactic and semantic requierements to combine interface and Implementation mixins 

  ```cpp
  // abilities 
  template <typename T>
  struct bells : T {
    void ring() {
      for_each(this, ability<ringable>. [](auto& a) {a.ring()});
    }
  };
  // associate abilities
  using guts = make_mixin<guts_impl, rinagble, magic_forg_power, allocator_use_capable>;
  ```

  * requirements: defined by the use 
  
  ```cpp
  // return type of mixin::compose

  template<typename... Ts>
  class composition : public call<detail::make_base<composition<Ts...>>, Ts...> {
    std::tuple<Ts...> data;
  };
  ```

  ```cpp
  // for_each (encapsulation)
  template <typename T, typename A,typename L>
  void for_each(access<T>* p, A, L l) {
    auto& data = p->get_data();
    // magic
  }
  ```

  ```cpp
  // inter implementation mixin access
  template <typename T>
  struct bells : T {
    void ring() {
      for_each(this, ability<ringable>. [a = access_to(this)](auto& m) {m.ring(a)});
    }
  };
  ```

  ```cpp
  template<typename... Ts>
  class composition : public call<detail::make_base<composition<Ts...>>, Ts...> {
    /*...*/
  public:
    composition(std::tuple<Ts...>&& d) : data{std::move(d)} {
      for_each(this, ability<requires_init_and_destruct>, detail::call_init(this));
    }
    ~composition() : data{std::move(d)} {
      for_each(this, ability<requires_init_and_destruct>, detail::call_destruct(this));
    }
  };
  ```

  ```cpp
  // dynamic mixins (passing a meta clousure aka factory)
  using guts = make_dynamic_mixin<fixed_buffer_factory, allocator>;
  

  template<typename... Ts>
  class composition : public call<detail::make_base<composition<Ts...>>, Ts...> {
    // store a tuple of meta functions
    std::tuple<call<Ts, Ts...> ...> data;
  };
  ```

  ```cpp
  template<typename B>
  struct widget_interface : B {
    
    template<typename E>
    auto dispatch_event(E& e) {
      return for_each(this, ability<widget_event_subscribe>, gather<E>, 
        [a = access_to(this), &](auto& m) { m_dispatch_event(e,a);}); 
    }

    template<typename E, typename A>
    auto dispatch_event(E& e, A a) {
      return for_each(this, ability<widget_event_subscribe>, gather<E>, 
        [&](auto& m) { m_dispatch_event(e,a);});
    }

  };
  ```

- [x] Odin Holmes: CppCon 2017 ["Agent based class design"](https://youtu.be/tNXyNa6kf4k)
  * extend policy based class design to agent based class design -> "build like legos"

- [x] Odin Holmes: CppNow 2019 ["Tacit DSL All the Thing"](https://youtu.be/J0jwUEyrvQM)
  * [code](https://github.com/odinthenerd/tmp)
  * functional dsl on top of ranges ?
  * DSL to write state machines

- [x] Mike Ritchie CppCon 2017 ["Microcontrollers in Micro-increments.."](https://youtu.be/XuHlDtWYeD8)
  * TDD for embedded development
  * TDD Setup: host only fullblown: [catch2](https://github.com/catchorg/Catch2), [trompeloeil](https://github.com/rollbear/trompeloeil), [fff](https://github.com/meekrosoft/fff)
  * Test-On-Target: [unity](http://www.throwtheswitch.org/unity), SEGGER Tools
    - as verification/integration tests
  * CI Build

```
checkout -> Unit Tests <debug, release>
         -> code coverage
         -> sanitizers <address, memory, ub>
         -> quality checks <tidy, static_analyzer>
         -> target test build
         -> test on target <logger, timeout>
         -> verify target test
         -> target build <debug, release, (release + debug info), release minsize>
         -> archive artifacts
         -> target deploy
```
  * Buildtools: docker, jenkins, cmake, git
  * [washing machine kata](https://evolvedhq.github.io/kata/)
```cpp
using hw_register = uint32_t volatile;

struct gpio_memory_layout {
    hw_register mode;                       // MODER
    hw_register output_type;                // OTYPEE
    hw_register output_speed;               // OSPEEDR
    hw_register pull_up_down_register;      // PUPDR
    hw_register input_data;                 // IDR
    hw_register ouput_data;                 // ODR
    hw_register bit_set_reset;              // BSRR
    hw_register locked;                     // LCKR
    hw_register alternative_function_low;   // AFRL (low word)
    hw_register alternative_function_high;  // AFRH (high word)
};

enum class pin_state {
    set, reset
};

class port {
public:
    void configure(input const& configuration);
    void configure(output const& configuration);
    // much detail omitted
    pin_state read(uint16_t pin) const;
    void write(uint16_t pin, pin_state state);
    void toggle_pin(uint16_t pin);

private:
    gpio_memory_layout memory;
};

stm32::gpio_memory_layout gpio_memory{.bit_set_reset = 0x0};
auto gpio_port = new(&gpio_memory) stm32::port;

using register_bits = std::bitset<32u>;
gpio_port->write(pin_number::pin3, pin_state::reset);
REQUIRE(register_bits(gpio_memory.bit_set_reset).test(3U));
```
```cpp
void reads_gpio_pin_with_pullup_resistor() {
  auto& gpio_port = stm32::port::placed_at(GPIOB);
  stm32::pin_state start_button_state = gpio_port.read(PTOG_START_Pin);
}
```

```cpp
mocks::mock_washer mock_washer;

stm32::gpio_memory_layout fake_memory{.input_data = 0x0};
auto& gpio_port = stm32::port::placed_at(&fake_memory);
/*...*/
if( gpio_port.read(DOOR_SWITCH_Pin) == stm32::pin_state::set ) {/*...*/}
```

- [ ] Gasper Azman: CppNow 2019 ["Points of Order in C++20"](https://youtu.be/WbW8A5QXn5I)
- [x] Gasper Azman: C++London 2020 ["`tag_invoke` - An Actually Good Way to Do Customization Points"](https://youtu.be/T_bijOA1jts)
- [x] Michael Wong - CppCon 2020 ["Modern Software Needs Embedded Modern C++ Programming"](https://youtu.be/885TI3jnB7g)
- [x] Luke Valenty - CppNow 2022 ["Embedded Logging Case Study: From C to Shining C++"](https://youtu.be/Dt0vx-7e_B0)
  * map log messages to integer ids (string hashes)
  * meta programming: create strings at compile time and store ids
  * [compile-time-init](https://github.com/intel/compile-time-init-build) [MIPI System Software Trace](https://github.com/MIPI-Alliance/public-mipi-sys-t)

```cpp
template <typename CharT, CharT... chars>
struct string_constant {
  constexpr static CharT storage[sizeof...(chars)]{chars...};

  using sv_t = std::basic_string_view<CharT>;
  constexpr static sv_t value{storage, sizeof...(chars)};

  constexpr operator sv_t() const noexcept { return value; }
  constexpr sv_t operator()() const noexcept { return value; }

  /*...*/
};
```
