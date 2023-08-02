---
layout: post
title: 'Type Erasure in C++: A callable reference'
date: '2023-07-30 07:33:43'
categories: ['C++', 'Type Erasure']
tags: ['c++', 'type erasure', 'functional', 'function_ref']
---

In my daily work I have regualarly a need to pass functions or callables around. 
If you want to implement a work queue or if you want to implement an observer 
you will have the need to pass and store callable objects.

> This is the fourth post in a series about type erasures:
> * [Part 1: The Basics][2]
> * [Part 2: A Polymorphic Type][3]
> * [Part 3: A Nonowning Type Erasure][4]
> * [Part 4: A callable reference][5]
{: .prompt-info }

## What do we have?

In C++ you have some option to do this out of the box: function pointers, 
[`std::function`][8], [`std::move_only_function`][9][^3] or templates. All this 
options come with there advantages and drawbacks.[^1] For me as an embedded c++ 
developer following points or importend:
1. easy to use and works with most callable objects
2. small overhead (small object size, no allocations, no exceptions)
3. no bloat and good to optimize

None of the provided options checks all critierias: 
* templates are not so easy to use and can potentially bloat the system[^2] 
* function pointer can not handle most callable objects
* [`std::function`][8] and [`std::move_only_function`][9] have a larger 
  object size to allow small buffer optimization or need dynamic memory and are 
  not easy to optimize by the compiler.

But gladly there is a proposal to provide an object which would be a better fit 
for many use cases: [`function_ref`: a type-erased callable reference][1].

## The Basics

The proposed [`function_ref`][1] is a lightweight non-owning generic callable 
object with reference semantic. This description makes it already similar to the 
[non-ownwing type erasure][4] described in the previous type erasure post. And 
the main idea is nearly identical: store the callable type eraused and store a 
function pointer to a lambda, which handles a type safe cast and is based on a 
generic constructor.

Let us start with a simple implementation to show how it works and than work 
our way up to the proposed implementation. At first we need to enforce a function 
signature as a template parameter. We do this via [partial template specialization][10]. 
We define at first the template prototype:

```cpp
template <typename>
class function_ref;
```
{: .nolineno}

This allows us to enforce a signature with a template specialization:

```cpp
template <typename RETURN_T, typename... ARG_Ts>
class function_ref<RETURN_T(ARG_Ts...)> {
  /* ... */
};
```
{: .nolineno}

The next step is to define our member parameters. We need a `void*` to store 
the address for our callable object: `void* m_callable{nullptr};`{: .cpp}. We also need 
a pointer to a function which will receive our `m_callable` together with all 
function parameters:

```cpp
using function_type = RETURN_T(void*, ARG_Ts...);
function_type* m_erased_fn{nullptr};
```
{: .nolineno}

Now we need to define a generic constructor which initializes our member variables. 
The address of a provided callable needs to be stort in `m_callable` and `m_erased_fn` 
needs to point at a function which will cast our callable back in his original 
type and than calls it with all parameters:
```cpp
template <typename CALLABLE_T>
    requires(!std::is_same_v<std::decay_t<CALLABLE_T>, function_ref>)
function_ref(CALLABLE_T&& callable) noexcept
    : m_callable{std::addressof(callable)}
    , m_erased_fn{[](void* ptr, ARG_Ts... args) -> RETURN_T {
          return (*static_cast<std::add_pointer_t<CALLABLE_T>>(ptr))(
              std::forward<ARG_Ts>(args)...);
      }} 
{}
```
{: .nolineno}

The last step is to define out call operator. This operator only needs to call 
`m_erased_fn` with our stored callable (`m_callable`) and all necessary 
parameters:

```cpp    
RETURN_T operator()(ARG_Ts... args) const {
  return m_erased_fn(m_callable, std::forward<ARG_Ts>(args)...);
}
```
{: .nolineno}

If we put all this together, it looks like this[^4][^5]:

```cpp
#include <memory>
#include <type_traits>

template <typename>
class function_ref;

template <typename RETURN_T, typename... ARG_Ts>
class function_ref<RETURN_T(ARG_Ts...)> {
   public:
    template <typename CALLABLE_T>
        requires(!std::is_same_v<std::decay_t<CALLABLE_T>, function_ref>)
    function_ref(CALLABLE_T&& callable) noexcept
        : m_callable{std::addressof(callable)}
        , m_erased_fn{[](void* ptr, ARG_Ts... args) -> RETURN_T {
              return (*static_cast<std::add_pointer_t<CALLABLE_T>>(ptr))(
                  std::forward<ARG_Ts>(args)...);
          }} 
    {}

    RETURN_T operator()(ARG_Ts... args) const {
        return m_erased_fn(m_callable, std::forward<ARG_Ts>(args)...);
    }

   private:
    using function_type = RETURN_T(void*, ARG_Ts...);
    void* m_callable{nullptr};
    function_type* m_erased_fn{nullptr};
};
```

We can use it similar to the [`std::function`][8] implementation of the first type 
erasure [post][2]. The code looks like[^4]:

```cpp
#include <iostream>
#include <vector>

struct dispatcher {
    void dispatch(const auto& msg) const noexcept {
        std::cout << "value: " << msg.value << '\n';
    }
};

struct int_message {
    int value = {};
};

struct float_message {
    float value = {};
};

int main() {
    using function_type = function_ref<void(const dispatcher&)>;

    std::vector<function_type> messages{[](const dispatcher& sink) { 
                                            int_message msg{.value = 42}; 
                                            sink.dispatch(msg);
                                        },
                                        [](const dispatcher& sink) { 
                                            float_message msg{.value = 3.14f}; 
                                            sink.dispatch(msg);
                                        },};

    dispatcher sink{};
    for (const auto& msg : messages) {
        msg(sink);
    }
}
```

In this code we create a vector of our `function_ref` type which stores the 
addresses of non-generic lambdas without capture and simply use the call 
operator for each of them inside the for loop.

## Construction 

The current implementation would allow a constructor call with any type. This 
will result in an unspecific compiler error. To improve this behavior we need 
to restrict the type for the constructor call. We can do so with [`std::is_invocable_r`][12]:

```cpp
template <typename CALLABLE_T>
  requires(!std::is_same_v<std::decay_t<CALLABLE_T>, function_ref> 
           && std::is_invocable_r_v<RETURN_T, CALLABLE_T&, ARG_Ts...>)
function_ref(CALLABLE_T&& callable) noexcept
```
{: .nolineno}

This would already improve the situation, but we can do better. The proposal defines 
the constraints as follow[^6]:

> Let `T` be `remove_reference_t<F>`.
> 
> Constraints:
> 
> * `remove_cvref_t<F>` is not the same type as `function_ref`,
> * `is_member_pointer_v<T>` is `false`, and
> * *`is-invocable-using<cv T&>`* is `true`.

Based on this constraints we need at first change [`std::decay`][13] to 
[`std::remove_cvref`][14][^7] and also we need to add the check for 
[std::is_member_pointer][15][^8]. The last constrain is tricky it is defined as:

> `template<class... T> static constexpr bool is-invocable-using = see below;`
>
> * If *noex* is `true`, *`is-invocable-using<T...>`* is equal to: `is_nothrow_invocable_r_v<R, T..., ArgTypes...>`
> * Otherwise, *`is-invocable-using<T...>`* is equal to: `is_invocable_r_v<R, T..., ArgTypes...>`

This means it is dependend on the exception specifier (*noex*). To distinquish 
this we need to define type traits which make the distinctions for us. The first 
trait we need needs is the detection of the exception specifier. We can define 
this via [partial template specialization][10]:

```cpp
namespace detail {

template<typename>
struct is_nothrow_fn;

template<typename RET_T, typename ... ARG_Ts>
struct is_nothrow_fn<RET_T(ARG_Ts...)> : std::false_type {};

template<typename RET_T, typename ... ARG_Ts>
struct is_nothrow_fn<RET_T(ARG_Ts...) const> : std::false_type {};

template<typename RET_T, typename ... ARG_Ts>
struct is_nothrow_fn<RET_T(ARG_Ts...) noexcept> : std::true_type {};

template<typename RET_T, typename ... ARG_Ts>
struct is_nothrow_fn<RET_T(ARG_Ts...) const noexcept> : std::true_type {};

template<typename FN_T>
static inline constexpr auto is_nothrow_fn_v = is_nothrow_fn<FN_T>::value;

}  // namespace detail
```

Now that we can distinquish the noexcept functions we specialize in the same way 
`is_invocable_using`:

```cpp
namespace detail {

template <typename, typename...>
struct is_invocable_using;

template <typename RET_T, typename... T, typename... ARG_Ts>
struct is_invocable_using<RET_T(ARG_Ts...), T...>
    : std::is_invocable_r<RET_T, T..., ARG_Ts...> {};

template <typename RET_T, typename... T, typename... ARG_Ts>
struct is_invocable_using<RET_T(ARG_Ts...) const, T...>
    : std::is_invocable_r<RET_T, T..., ARG_Ts...> {};

template <typename RET_T, typename... T, typename... ARG_Ts>
struct is_invocable_using<RET_T(ARG_Ts...) noexcept, T...>
    : std::is_nothrow_invocable_r<RET_T, T..., ARG_Ts...> {};

template <typename RET_T, typename... T, typename... ARG_Ts>
struct is_invocable_using<RET_T(ARG_Ts...) const noexcept, T...>
    : std::is_nothrow_invocable_r<RET_T, T..., ARG_Ts...> {};

template <typename FN_T, typename... T>
static inline constexpr auto is_invocable_using_v =
    is_invocable_using<FN_T, T...>::value;

}  // namespace detail
```

The next thing we need is *`cv`* which was defined as either `const` or empty. So 
let us implement a trait for that. At first we define a trait which checks if 
we have a const function:

```cpp
namespace detail {

template <typename>
struct is_const_fn;

template <typename RET_T, typename... ARG_Ts>
struct is_const_fn<RET_T(ARG_Ts...)> : std::false_type {};

template <typename RET_T, typename... ARG_Ts>
struct is_const_fn<RET_T(ARG_Ts...) const> : std::true_type {};

template <typename RET_T, typename... ARG_Ts>
struct is_const_fn<RET_T(ARG_Ts...) noexcept> : std::false_type {};

template <typename RET_T, typename... ARG_Ts>
struct is_const_fn<RET_T(ARG_Ts...) const noexcept> : std::true_type {};

template <typename FN_T>
static inline constexpr auto is_const_fn_v = is_const_fn<FN_T>::value;

}  // namespace detail
```

We can now use this trait to define our *`cv`*:

```cpp
namespace detail {

template <typename FN_T, typename T, bool is_const = is_const_fn_v<FN_T>>
struct cv {
    using type = const T;
};

template <typename FN_T, typename T>
struct cv<FN_T, T, false> {
    using type = T;
};

template <typename FN_T, typename T>
using cv_t = typename cv<FN_T, T>::type;

}  // namespace detail
```

If we put everything together our constructor signature looks like[^9]:

```cpp
template <typename CALLABLE_T, typename T = std::remove_reference_t<CALLABLE_T>>
    requires(!std::is_same_v<std::remove_cvref_t<CALLABLE_T>, function_ref> &&
             !std::is_member_pointer_v<T> &&
             detail::is_invocable_using_v<RETURN_T(ARG_Ts...), 
                                          detail::cv_t<RETURN_T(ARG_Ts...), CALLABLE_T>&>)
constexpr function_ref(CALLABLE_T&& callable) noexcept
```
{: .nolineno}

Now our constructor looks like it should, but we can not handle all signatures. 
The current template specialization is not defined to handle `const` and `noexcept` 
signatures. This means we can not handle calls like:

```cpp
function_ref<void(int) noexcept> f{[](int) noexcept {}};
```
{: .nolineno}


Like most problems we can solve this with indirections. We extend and 
rename our `function_ref` template class so that it stores the complete signature 
informations and than simply aliase the class for the public API.

We rename the `function_ref` class to `function_ref_base` and move it into our 
`detail` namespace. Next we need to change the template parameters:

```cpp
template <typename, typename>
class function_ref_base;

template <typename SIG_T, typename RET_T, typename... ARG_Ts>
class function_ref_base<SIG_T, RET_T(ARG_Ts...)>
```
{: .nolineno}

The parameter `SIG_T` now stores the complete signature informations. We can 
use this informations to extract what we need:

```cpp
static constexpr bool is_nothrow = is_nothrow_fn_v<SIG_T>;
static constexpr bool is_const = is_const_fn_v<SIG_T>;

template <typename... T>
static constexpr bool is_invocable_using = is_invocable_using_v<SIG_T, T...>;

template <typename T>
using cv = typename detail::cv_t<SIG_T, T>;
```
{: .nolineno}

With this in place we can now proper define the exception specifier for our 
internal function ptr:

```cpp
using function_type = RET_T(void*, ARG_Ts...) noexcept(is_nothrow);
```
{: .nolineno}

And also adapt our constructor accordingly:

```cpp
template <typename CALLABLE_T,typename T = std::remove_reference_t<CALLABLE_T>>
    requires(!std::is_same_v<std::remove_cvref_t<CALLABLE_T>, function_ref_base> &&
             !std::is_member_pointer_v<T> && 
             is_invocable_using<cv<T>&>)
constexpr function_ref_base(CALLABLE_T&& callable) noexcept
    : m_callable{std::addressof(callable)},
      m_erased_fn{[](void* ptr, ARG_Ts... args) noexcept(is_nothrow) -> RET_T {
          return (*static_cast<std::add_pointer_t<CALLABLE_T>>(ptr))(
              std::forward<ARG_Ts>(args)...);
      }} {}
```
{: .nolineno}

The last step here is to define the alias and extract the need information for 
the construction of `function_ref_base`. To do so we at first need to define 
additional traits to extract the signature:

```cpp
namespace detail {

template <typename>
struct fn_signature;

template <typename RET_T, typename... ARG_Ts>
struct fn_signature<RET_T(ARG_Ts...)> {
    using type = RET_T(ARG_Ts...);
};

template <typename RET_T, typename... ARG_Ts>
struct fn_signature<RET_T(ARG_Ts...) const> {
    using type = RET_T(ARG_Ts...);
};

template <typename RET_T, typename... ARG_Ts>
struct fn_signature<RET_T(ARG_Ts...) noexcept> {
    using type = RET_T(ARG_Ts...);
};

template <typename RET_T, typename... ARG_Ts>
struct fn_signature<RET_T(ARG_Ts...) const noexcept> {
    using type = RET_T(ARG_Ts...);
};

template <typename FN_T>
using fn_signature_t = typename fn_signature<FN_T>::type;

}  // namespace detail
```
{: .nolineno}

Now we can define our alias:

```cpp
template <typename SIG_T>
using function_ref = detail::function_ref_base<SIG_T, typename detail::fn_signature_t<SIG_T>>;
```
{: .nolineno}

> The use of an alias here is different to the [proposal][1] and could end up 
> in a different lookup behavior. An alternative implementation would be to 
> extend the signature for `function_ref` directly, like it was done in 
> [zhihaoy/nontype_functional@p0792r13.][17] 
{: .prompt-warning }

With all this in place we are now able to handle `noexcept` correctly and also 
constructions are now possible[^10]: 
```cpp 
function_ref<void(int) noexcept> f{[](int) noexcept {}};
```
{: .nolineno}

## Function Pointers and Storage

The current implementation stores everthing as a `void*` which makes sense for 
functors but not so much for function pointers.[^11] The [proposal][1] defines 
a dedicated constructor to support function pointers[^6]:

> `template<class F> function_ref(F* f) noexcept;`
>
> **Constraints:**
> * `is_function_v<F>` is `true`, and
> * is_ *`is-invocable-using<F>`* is `true`.
>
> **Preconditions:** `f` is not a null pointer.
> 
> **Effects:** Initializes *`bound-entity`* with `f`, and *`thunk-ptr`* with the address 
> of a function *`thunk`* such that *`thunk(bound-entity, call-args...)`* is 
> expression-equivalent to `invoke_r<R>(f, call-args...)`.


This means for us we need to implement the constructor and also implement a 
storage which will support both constructions. Let us first take a look at the 
storage. We need to store the pointer to a functor **or** a pointer to a function. 
We can use `void*` to store the functor, and to store the function pointer we 
can use any kind of function pointer so we can use `void (*)()`. This is 
possible because we have a guarantee that we can convert it back without 
changing the value. The [C++ Standard](wg21.link//N4849) says about this:

> A function pointer **can be explicitly converted to a function pointer of a 
different type**. [...] Except that **converting** a prvalue of type “pointer to T1” 
**to the type** “pointer to T2” (where T1 and T2 are function types) **and back to its 
original type yields the original pointer value**, the result of such a pointer 
conversion is unspecified.
([C++ Standard Draft N4849](wg21.link//N4849) section *7.6.1.9/6 [expr.reinterpret.cast]*)
{: .prompt-info }

Or [C++ reference](https://en.cppreference.com/w/cpp/language/reinterpret_cast) pharses it like:

> Any **pointer to function can be converted to a pointer to a different function 
> type**. Calling the function through a pointer to a different function type is 
> undefined, but **converting such pointer back** to pointer to the original function 
> type **yields the pointer to the original function**.

This means we can store the function pointer as a different type as long as we 
ensure to access it only after we restore the original type. To store the 
different pointer types we can use an `union`[^12]:

```cpp
union storage_t {
  void* obj_ptr{nullptr}
  void (*fn_ptr)(){nullptr};
};
```
{: .nolineno}

## Summary so far

## References

### Blogs

* [Vittorio Romeo][6]: [passing functions to functions](https://vittorioromeo.info/index/blog/passing_functions_to_functions.html)
* [Foonathan][7]: [Implementing `function_view` is harder than you might think][16]

### Paper 

* P0792: [`function_ref: a type-erased callable reference`][1]

### Videos

* Vittorio Romeo: Meeting C++ 2017 [Lightning Talk: `function_ref`](https://youtu.be/6EQRoqELeWc)
* Vittorio Romeo: CppNow 2019 [Higher-order functions and `function_ref`](https://youtu.be/5V74RPUEu5s)

### Code

* [zhihaoy/nontype_functional@p0792r13][17] complete implementation of `function_ref`
* [`llvm::function_ref`][11] implementation used by to LLVM Project
* [`tl::function_ref`](https://github.com/TartanLlama/function_ref) implementation by *Tartan Llama*

## Footnotes

[^1]: The proposal [P0792][1] provides a good overview over the advantages and disadvantages.
[^2]: Jason Turner wrote an article about this: [template code bloat](https://articles.emptycrate.com/2008/05/06/nobody_understands_c_part_5_template_code_bloat.html)
[^3]: `std::move_only_function` will be part of [C++23](https://en.cppreference.com/w/cpp/23) and was proposed in [P0288](wg21.link/p0288r9)
[^4]: You can find the example in compiler explorer: [https://godbolt.org/z/evorMPo58](https://godbolt.org/z/evorMPo58) 
[^5]: This implementation is a slightly simplified version of [`llvm::function_ref`][11]
[^6]: This is based on [P0792r14](wg21.link/p0792r14)
[^7]: [`std::decay`][13] makes a unwanted type conversions for our case e.g.: change arrays to pointers
[^8]: The blog post [Implementing `function_view` is harder than you might think][16] provides an explaination why member pointers are not supported 
[^9]: You can find the example in compiler explorer: [https://godbolt.org/z/sM57zvdxa](https://godbolt.org/z/sM57zvdxa)
[^10]: You can find the example in compiler explorer: [https://godbolt.org/z/b638nrM7z](https://godbolt.org/z/b638nrM7z)
[^11]: This was pointed out in: [Implementing `function_view` is harder than you might think][16]
[^12]: This is similar to the implementation provided by [zhihaoy/nontype_functional@p0792r13][17]

[1]: wg21.link/p0792r14
[2]: {% post_url 2023-05-21-type-erasure-the-basics%}
[3]: {% post_url 2023-05-28-type-erasure-polymorphic-type%}
[4]: {% post_url 2023-07-29-type-erasure-nonowning%}
[5]: {% post_url 2023-07-29-type-erasure-nonowning%}
[6]: https://vittorioromeo.info/index.html 
[7]: https://www.foonathan.net/
[8]: https://en.cppreference.com/w/cpp/utility/functional/function
[9]: https://en.cppreference.com/w/cpp/utility/functional/move_only_function
[10]: http://en.cppreference.com/w/cpp/language/partial_specialization
[11]: https://github.com/llvm/llvm-project/blob/llvmorg-16.0.6/llvm/include/llvm/ADT/STLFunctionalExtras.h
[12]: https://en.cppreference.com/w/cpp/types/is_invocable
[13]: https://en.cppreference.com/w/cpp/types/decay 
[14]: https://en.cppreference.com/w/cpp/types/remove_cvref
[15]: https://en.cppreference.com/w/cpp/types/is_member_pointer
[16]: https://www.foonathan.net/2017/01/function-ref-implementation/
[17]: https://github.com/zhihaoy/nontype_functional/blob/p0792r13/include/std23/function_ref.h
