---
layout: post
title: 'Reinventing the Wheel: function_ref'
date: '2023-08-05 23:00:35'
categories: ['C++', 'Reinventing the Wheel']
tags: ['c++', 'type erasure', 'functional', 'function_ref']
---

In a [previous blog post][1], I briefly overviewed `function_ref`. The implementation provided has some serious flaws. In the current post, I want to dig into these flaws and create an implementation that is closer to the [`function_ref` proposal (P0792)][2].

> This post describes an implementation of a `function_ref` class step by step. This journey will be pretty long; if you want to see the final product up front, you can do so on [compiler explorer][30] and [cpp insights][31].
{: .prompt-info}

## Design Flaws

In the [overview post][1] I provided following implementation[^1]:

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

This implementation has several significant flaws. Let us detect the defects and start with a new implementation based on the [standard proposal][2].
***A note up front:*** The blog post [Implementing `function_view` is harder than you might think][5] already mentioned most of the flaws. I recommend reading this post. 

### function pointers

The first flaw is that our `function_ref` does not work with functions only 
with functors. So the following will not compile:
```cpp
int foo() { return 42; }
function_ref<int()> fn(foo);
```
{: .nolineno}

The issue is that we try to store everything as `void*`, but the cast of a 
function pointer into a `void*` would not be safe. The standard says this:

> The type of a pointer to cv `void` or a pointer to an object type is called an 
> ***object pointer*** type. [...] The type of a pointer that can designate a function 
> is called a ***function pointer*** type. ([C++ Standard Draft N4849][7] section *6.8.2/3 [[basic.compound]]*)

> A pointer to cv-qualified or cv-unqualified `void` **can be used to point to 
> objects** of unknown type. Such a pointer shall be able to **hold any object pointer**. 
> An object of type cv `void*` shall have the same representation and alignment 
> requirements as cv `char*`. ([C++ Standard Draft N4849][7] section *6.8.2/5 [[basic.compound]]*)

This description means `void*` can **only** hold object pointers safely. If we want to store function pointers, we need a different storage type. 

### `const` and `noexcept`

A function in C++ can have a cv qualification and an exception specification. If we try it with our implementation, we get a compilation error because of incomplete types. 
```cpp
// compilation error:
function_ref<int() noexcept> foo([]() noexcept {return 42;});
```
{: .nolineno}

This error happens because our [partial template specialization][8] supports only one kind of signature, and this signature does not consider this additional qualification/specification. So we also need to add support for this qualification and evaluate this information for our member functions.

### Better support for free and member functions

The current implementation restricts the use of member functions and free functions and needs to be more user-friendly. So code like this is currently not possible: 

```cpp
struct A {
    int bar() { return 17; }
};
A a;

// compilation error:
function_ref<int()> foo(&A::bar, a);
```
{: .nolineno}

The [standard proposal][2] contains dedicated constructors to support these functions better using `nontype_t`. We should also add 
support for `nontype_t` to provide the same functionality.

## Implementation Plan

This blog post will implement a `function_ref` similar to the [proposal][2].
We will do this step by step and explain the implementation. 
The API, in the end, should look like this[^2]:

```cpp
template<class... S> class function_ref;    // not defined

template<class R, class... ArgTypes>
class function_ref<R(ArgTypes...) cv noexcept(noex)>
{
public:
  // [func.wrap.ref.ctor], constructors and assignment operators
  template<class F> function_ref(F*) noexcept;
  template<class F> constexpr function_ref(F&&) noexcept;
  template<auto f> constexpr function_ref(nontype_t<f>) noexcept;
  template<auto f, class U>
    constexpr function_ref(nontype_t<f>, U&&) noexcept;
  template<auto f, class T>
    constexpr function_ref(nontype_t<f>, cv T*) noexcept;

  constexpr function_ref(const function_ref&) noexcept = default;
  constexpr function_ref& operator=(const function_ref&) noexcept = default;
  template<class T> function_ref& operator=(T) = delete;

  // [func.wrap.ref.inv], invocation
  R operator()(ArgTypes...) const noexcept(noex);
private:
  template<class... T>
    static constexpr bool is-invocable-using = see below;   // exposition only
};

// [func.wrap.ref.deduct], deduction guides
template<class F>
  function_ref(F*) -> function_ref<F>;
template<auto f>
  function_ref(nontype_t<f>) -> function_ref<see below>;
template<auto f>
  function_ref(nontype_t<f>, auto) -> function_ref<see below>;
```
{: .nolineno}

> In our journey, we will take a lot of inspiration from the example implementation: [zhihaoy/nontype_functional@p0792r13][6]. Also, when it is not explicitly mentioned, you can assume that I checked the implementation in this code upfront, which will have impacted the implementation.
{: .prompt-info}

## Support for *functors*

We will start over from scratch. So we should at first implement what the 
previous implementation already can: support for [*functors*][9] and other 
[*callable objects*][10].

*functor*
: A *functor* in C++ describes a [function object][9], which means an object 
that overloads one or more function call operators (`operator()`).

*callable objects*
: A type for which the [*`INVOKE`*][11] and [*`INVOKE<R>`*][11] operations are applicable.[^3]

So after this, we will be able to construct our `function_ref` like this:

```cpp
struct functor {
    int operator()() { return 42; }
};

functor func{};
function_ref<int()> fn_ref1(func);
function_ref<int()> fn_ref2([]() {return 17;});
```
{: .nolineno}

We have a lot of leg work for our first implementation, so let us dig 
directly into it. We need to define our class and constructor, and we already need to implement the necessary restriction for our constructor.

### Class declaration

The [proposal][2] declares the function ref class as follows:

```cpp
template<class... S> class function_ref;    // not defined

template<class R, class... ArgTypes>
class function_ref<R(ArgTypes...) cv noexcept(noex)> {/*...*/}
```
{: .nolineno}

> The header provides partial specializations of `function_ref` for each 
> combination of the possible replacements of the placeholders *cv* and *noex* 
> where:
> * *cv* is either `const` or empty.
> * *noex* is either `true` or `false`.

So we need to support the following specializations:

```cpp
template <typename ... S>
class function_ref;

template <typename R, typename ... ARG_Ts>
class function_ref<R(ARG_Ts...)> {};
// to support: function_ref<int()> fnref{/*...*/};

template <typename R, typename ... ARG_Ts>
class function_ref<R(ARG_Ts...) const> {};
// to support: function_ref<int() const> fnref{/*...*/};

template <typename R, typename ... ARG_Ts>
class function_ref<R(ARG_Ts...) noexcept> {};
// to support: function_ref<int() noexcept> fnref{/*...*/};

template <typename R, typename ... ARG_Ts>
class function_ref<R(ARG_Ts...) const noexcept> {};
// to support: function_ref<int() const noexcept> fnref{/*...*/};
```
{: .nolineno}

Supporting all four specializations independently would be a lot 
of effort. So we need to align the implementation effort. We have multiple 
possibilities to do so[^4]:
1. inherit from a common base class
2. create a common base class, but use an [alias][15] as `function_ref`
3. define a different signature for the specializations

#### Inheritance

We have a price to pay if we use inheritance to reduce the implementation effort. We would need public inheritance to avoid code duplications; this 
means we need to take care of the destructor of our base class.[^5] If we 
need to create a virtual function, our class would not be [trivial][13] anymore, and we could get problems with [the standard layout][14] of our class. Beyond this, we could get suboptimal padding for our `function_ref` class, which would increase to object size.

#### Alias

We could change the class declaration to an alias like:
```cpp
template<typename R, typename... ARG_Ts, bool is_nothrow, bool is_const>
class function_ref_base<R(ARG_Ts...), is_nothrow, is_const> {/*...*/};

template<typename SIG_T>
using function_ref = function_ref_base<signatur_t<SIG_T>, is_nothrow_v<SIG_T>, is_const_v<SIG_T> >;
```
{: .nolineno}

The good thing about an [alias][15] is that it does not create any overhead for the object and will not change its layout. This solution also has some 
severe drawbacks. The most obvious is that we need to break with the 
[proposed][2] declaration completely. A more severe issue in the usage would be having a different [lookup behavior][16]. An [alias][15] is not 
considered for an [argument-dependent lookup][16]; this means we can not use it in the same way as we could use it as a class.

#### Signature Change

The third option to fix the issue would be to change the signature for our 
implementation. The [reference implementation][6] has chosen this variant. There the template class declaration looks like this:

```cpp
template<class Sig, class = typename _qual_fn_sig<Sig>::function>
class function_ref; // freestanding

template<class Sig, class R, class... Args>
class function_ref<Sig, R(Args...)> // freestanding
```
{: .nolineno}

The prototype now takes exactly two and not a variable amount of template parameters, and the specialization now takes the complete function signature as the first parameter (including *cv qualifier* and *exception specifier*) and the function types as the second parameter (return type and parameter list). With both pieces of information available, we can detect everything necessary for one generic implementation, which would still match most expected use cases.

We will go for the same approach in our implementation, but remember that this signature change is a simplification; we should specialize for all four types.

#### Implementation

To implement the class declaration, we must first implement a type trait that will extract our function types from the provided signature. To implement this trait, we will use [partial template specialization][8]:

```cpp
namespace detail {
template <typename> struct fn_types;

template <typename R, typename... ARG_Ts>
struct fn_types<R(ARG_Ts...)> { using type = R(ARG_Ts...); };

template <typename R, typename... ARG_Ts>
struct fn_types<R(ARG_Ts...) const> { using type = R(ARG_Ts...); };

template <typename R, typename... ARG_Ts>
struct fn_types<R(ARG_Ts...) noexcept> { using type = R(ARG_Ts...); };

template <typename R, typename... ARG_Ts>
struct fn_types<R(ARG_Ts...) const noexcept> { using type = R(ARG_Ts...); };

template <typename SIG_T>
using fn_types_t = typename fn_types<SIG_T>::type;

}  // namespace detail
```
{: .nolineno}

The trait `fn_types` will extract the function types for each provided signature. For convenience, we also add an [alias][15] `fn_types_t`. This trait allows us now to implement our class declarations:

```cpp
template <typename SIG_T, typename = detail::fn_types_t<SIG_T>>
class function_ref;

template <typename SIG_T, typename R, typename... ARG_Ts>
class function_ref<SIG_T, R(ARG_Ts...)> {};
```
{: .nolineno}

We only need to provide our function signature if we want to use the class. The default parameter will be triggered, which will then end up in our template specialization. Now we can create our `function_ref` objects with exception specifier and const qualifier:

```cpp
function_ref<int()> fnref;
function_ref<int() const> cfnref;
function_ref<int() noexcept> exfnref;
function_ref<int() const noexcept> cexfnref;
```
{: .nolineno}

You can see the progress we made so far in  [compiler explorer](https://godbolt.org/z/nxaa7sGcf), or if you want to see more about what happens in [cpp insights](https://cppinsights.io/s/c9bb50cd).

### The *`noex`* trait

Many implementations in the [proposal][2] depend on the exception specifier. To check if our signature is `noexcept`, we need to implement an additional type trait:

```cpp
namespace detail {
template <typename> struct is_nothrow_fn;

template <typename R, typename... ARG_Ts>
struct is_nothrow_fn<R(ARG_Ts...)> : std::false_type {};

template <typename R, typename... ARG_Ts>
struct is_nothrow_fn<R(ARG_Ts...) const> : std::false_type {};

template <typename R, typename... ARG_Ts>
struct is_nothrow_fn<R(ARG_Ts...) noexcept> : std::true_type {};

template <typename R, typename... ARG_Ts>
struct is_nothrow_fn<R(ARG_Ts...) const noexcept> : std::true_type {};

template <typename SIG_T>
inline constexpr bool is_nothrow_fn_v = is_nothrow_fn<SIG_T>::value;
}  // namespace detail
```
{: .nolineno}

This trait is specialized for each function qualifier and will be a 
[`std::true_type`][17] if we are in the `noexcept` context. This information will be used often in the following code so we can store it directly in our class as a private member:

```cpp
static constexpr bool noex = detail::is_nothrow_fn_v<SIG_T>;
```
{: .nolineno}

### Storage Type

If we want to implement the constructor for [*callable objects*][10], we must also store a pointer to the object and our function call. The [proposal][2] defines this as follows:

> An object of class `function_ref<R(Args...) cv noexcept(noex)>` stores a 
> pointer to function *`thunk-ptr`* and an object *`bound-entity`*. *`bound-entity`* 
> has an unspecified trivially copyable type *`BoundEntityType`*, that models 
> `copyable` and is capable of storing a pointer to object value or a pointer 
> to function value. The type of *`thunk-ptr`* is 
> `R(*)(BoundEntityType, Args&&...) noexcept(noex)`.

There is a bit to unpack her. At first, it defines that our storage type 
needs to store a pointer to an object or function value. It also specifies that this object (called *`BoundEntityType`*) needs to be [trivially copyable][18]. Additionally, it defines how our function pointer (called *`thunk-ptr`*) needs to be declared; we will dig into this pointer later. Let us start with the storage type.

We know we need to store either a pointer to an object or a function value. So we must implement a `variant` or `union`.Currently, we only care about objects, so we only care that we can extend later 
with a function pointer. Now let us define our `union`:

```cpp
namespace detail {
union bound_entity_type {
  void* obj_ptr{nullptr};

  constexpr bound_entity_type() noexcept = default;
  
  template<typename T> requires std::is_object_v<T>
  constexpr explicit bound_entity_type(T* ptr) noexcept : obj_ptr(ptr) {}
};

static_assert(std::is_trivially_copyable_v<bound_entity_type>);
}  // namespace detail
```
{: .nolineno}

This short piece of code defines our storage type for now. It currently only supports the construction via object pointer, and the [`static_assert`][19] ensures we fulfill the object requirements. Now we only need to define our function pointer and add the members to our class. We first add [aliases][15] for our member types[^6], and then we can define our members:

```cpp
using bound_entity_t = detail::bound_entity_type;
using thunk_ptr_t = R(*)(bound_entity_t, ARG_Ts...) noexcept(noex);

bound_entity_t m_bound_entity{};
thunk_ptr_t m_thunk_ptr{nullptr};
```
{: .nolineno}

### The *`is-invocable-using`* trait

Be for we can define our constructor, we need to take care of one additional property: `is-invocable-using<T...>`. This property has to be defined as a static member template of our class, and the specification says:

> `template<class... T> static constexpr bool is-invocable-using = see below;`
>
> * If *noex* is `true`, *`is-invocable-using<T...>`* is equal to: `is_nothrow_invocable_r_v<R, T..., ArgTypes...>`
> * Otherwise, *`is-invocable-using<T...>`* is equal to: `is_invocable_r_v<R, T..., ArgTypes...>`

 We can define a trait to detect the right `invocable` trait based on our `is_nothrow_fn` trait:

```cpp
namespace detail {
template<typename, bool, typename...>
struct is_invocable_using;

template <typename R, typename... ARG_Ts, typename ... T>
struct is_invocable_using<R(ARG_Ts...), true, T...> : std::is_nothrow_invocable_r<R, T..., ARG_Ts...> {};

template <typename R, typename... ARG_Ts, typename ... T>
struct is_invocable_using<R(ARG_Ts...), false, T...> : std::is_invocable_r<R, T..., ARG_Ts...> {};

template <typename SIG_T, typename ... T>
inline constexpr bool is_invocable_using_v = is_invocable_using<fn_types_t<SIG_T>, is_nothrow_fn_v<SIG_T>, T...>::value;
}  // namespace detail
```
{: .nolineno}

With this trait in place, we can now define it as a member of our class:

```cpp
template <typename... T>
static constexpr bool is_invocable_using = detail::is_invocable_using_v<SIG_T, T...>;
```
{: .nolineno}

### Callable Object Construction

Now have everything we need to implement the constructor for [*callable objects*][10]. The constructor definition says:

> `template<class F> constexpr function_ref(F&& f) noexcept;`
>
>  Let `T` be `remove_reference_t<F>`.
>
> ***Constraints:***
> * `remove_cvref_t<F>` is not the same type as `function_ref`,
> * `is_member_pointer_v<T>` is `false`, and
> * `is-invocable-using<cv T&>` is true.
>
> ***Effects:*** Initializes *`bound-entity`* with `addressof(f)`, and *`thunk-ptr`* 
> with the address of a function thunk such that *`thunk(bound-entity, call-args...)`* 
> is expression-equivalent to `invoke_r<R>(static_cast<cv T&>(f), call-args...)`.

So let us start with the declaration of the constructor. The signature is already given by the [proposal][2]:

```cpp
template <typename F, typename T = std::remove_reference_t<F>>
constexpr function_ref(F&& f) noexcept;
```
{: .nolineno}

We added the second template parameter to reduce the typing effort and be more conform with the writings of the [proposal][2]. We must add the constraints as a [requires clause][20]. Let us start with the first two restrictions:

```cpp
template <typename F, typename T = std::remove_reference_t<F>>
    requires(!std::is_same_v<std::remove_cvref_t<F>, function_ref> &&
             !std::is_member_pointer_v<T>)
constexpr function_ref(F&& f) noexcept;
```
{: .nolineno}

The third constraint is slightly more complex and needs some upfront work. The [proposal][2] defines this constraint as `is-invocable-using<cv T&>`. The value for *`cv`* is defined as empty or `const` based on the const qualifier of our function signature. So we need to define a trait to check for the value and to do the type conversion for us. The implementation is similar to what we have done for `noexcept`. The trait to check for constness looks like this:

```cpp
namespace detail {
template <typename>
struct is_const_fn;

template <typename R, typename... ARG_Ts>
struct is_const_fn<R(ARG_Ts...)> : std::false_type {};

template <typename R, typename... ARG_Ts>
struct is_const_fn<R(ARG_Ts...) const> : std::true_type {};

template <typename R, typename... ARG_Ts>
struct is_const_fn<R(ARG_Ts...) noexcept> : std::false_type {};

template <typename R, typename... ARG_Ts>
struct is_const_fn<R(ARG_Ts...) const noexcept> : std::true_type {};

template <typename SIG_T>
inline constexpr bool is_const_fn_v = is_const_fn<SIG_T>::value;
}  // namespace detail
```
{: .nolineno}

The conversion needs to distinguish between const and not. The 
implementation would look like this:

```cpp
namespace detail {
template <typename T, bool is_const = true>
struct cv_fn {
    using type = const T;
};

template <typename T>
struct cv_fn<T, false> {
    using type = T;
};

template <typename SIG_T, typename T>
using cv_fn_t = typename cv_fn<T, is_const_fn_v<SIG_T>>::type;
}  // namespace detail
```
{: .nolineno}

For convenience, we will also add the [alias][15] to our class:

```cpp
template<typename T>
using cv = typename detail::cv_fn_t<SIG_T, T>;
```
{: .nolineno}

With this in place, we can now also define our last constrain:

```cpp
template <typename F, typename T = std::remove_reference_t<F>>
    requires(!std::is_same_v<std::remove_cvref_t<F>, function_ref> &&
             !std::is_member_pointer_v<T> && 
             is_invocable_using<cv<T>&>)
constexpr function_ref(F&& f) noexcept;
```
{: .nolineno}

Now the only thing we need to add is the initialization of our member variables. We can initialize our storage precisely like it is defined via [`std::addressof`][21]: `m_bound_entity{std::addressof(f)}`{: .cpp}. The initialization of the`m_thunk_ptr`member is more complicated. We need to create a concrete lambda expression without capture to store the pointer of the lambda expression in our function pointer. This approach is the same as for the [non-owning type erasure][22]. This pointer assignment is well-defined behavior:

> The closure type for a **non-generic** lambda-expression with **no lambda-capture** 
> whose constraints (if any) are satisfied has a **conversion function to pointer 
> to function** with C++ language linkage having the same parameter and return 
> types as the closure type’s function call operator. ([C++ Standard Draft N4849][7] section *7.5.5.1/7 [expr.prim.lambda.closure]*)

This lambda needs to fulfill the signature `R (*)(bound_entity_t, ARG_Ts...) noexcept(noex)`. It must extract the object pointer from our storage, call the call operator with the provided arguments, and return the value if the return type is not `void`.

At first, we implement a utility function to extract object pointers from our storage:
```cpp
namespace detail {
template <typename T>
constexpr static auto get(bound_entity_type entity) {
    return static_cast<T*>(entity.obj_ptr);
}
}  // namespace detail
```
{: .nolineno}

This function extracts our object pointer and casts it into the expected type. Now we can define our lambda expression:

```cpp
[](bound_entity_t entity, ARG_Ts... args) noexcept(noex) -> R {
    cv<T>& obj = *get<T>(entity);
    if constexpr (std::is_void_v<R>) {
        std::invoke(obj, std::forward<ARG_Ts>(args)...);
    } else {
        return std::invoke(obj, std::forward<ARG_Ts>(args)...);
    }
}
```
{: .nolineno}

This call makes what we have described. It gets the object pointer as 
reference applies the needed const qualification (`cv<T>`) and then calls the function in dependency of the return type. With this in place, the constructor is now complete: 

```cpp
template <typename F, typename T = std::remove_reference_t<F>>
    requires(!std::is_same_v<std::remove_cvref_t<F>, function_ref> &&
             !std::is_member_pointer_v<T> && 
             is_invocable_using<cv<T>&>)
constexpr function_ref(F&& f) noexcept
: m_bound_entity{std::addressof(f)}
, m_thunk_ptr{
      [](bound_entity_t entity, ARG_Ts... args) noexcept(noex) -> R {
         cv<T>& obj = *get<T>(entity);
         if constexpr (std::is_void_v<R>) { std::invoke(obj, std::forward<ARG_Ts>(args)...); } 
         else { return std::invoke(obj, std::forward<ARG_Ts>(args)...); }
     }} 
{}
```
{: .nolineno}

### Callable Operator

We can already construct `function_ref` objects. But to see if it works, we also need the call operator. Luckily this is an easy task. The [proposal][2] description for this operator is as follows:

> `R operator()(ArgTypes... args) const noexcept(noex);`
> ***Effects:*** Equivalent to: `return thunk-ptr(bound-entity, std::forward<ArgTypes>(args)...);`

Let us implement precisely that:

```cpp
R operator()(ARG_Ts... args) const noexcept(noex) {
    return m_thunk_ptr(m_bound_entity, std::forward<ARG_Ts>(args)...);
}
```
{: .nolineno}

And that's it. We are now able to construct and call our `function_ref`. We can test our implementation:

```cpp
#include <cassert>

struct functor {
    int operator()([[maybe_unused]] char) const { return 42; }
    void operator()([[maybe_unused]] bool) noexcept {}
    int operator()() const noexcept { return 17; }
};

functor fun{};
function_ref<int()> fnref{[]() { return 17; }};
function_ref<int(char) const> cfnref{fun};
function_ref<void(bool) noexcept> exfnref{fun};
function_ref<int() const noexcept> cexfnref{fun};

assert((fnref() == 17));
assert((cfnref('a') == 42));
exfnref(false);
assert((cexfnref() == 17));
```
{: .nolineno}

Now we can do everything the [*quick and dirty* implementation][1] could do but in a more defined manner. If you want to look at the implementation we have done so far, you can see it in [cpp insight](https://cppinsights.io/s/905b784b) or [compiler explorer](https://godbolt.org/z/K1KzWqKs1).


## Support for *const functors*

The hardest parts are now behind us. But our current implementation still needs to improve: we can not handle const functors. If we try to construct with const as the following code:

```cpp
const functor cfun{};
function_ref<int(char) const> cfnref{cfun};
function_ref<int() const noexcept> cexfnref{cfun};

assert((cfnref('a') == 42));
assert((cexfnref() == 17));
```
{: .nolineno}

The compiler will complain about an invalid conversion between `const void*` and `void*`. To fix this issue, we need to extend our `bound_entity_type` with support for const pointers. To do so, we need to add a representation for `const void*` to our `union` and add the matching constructor.

```cpp
union bound_entity_type {
    /*...*/
    const void* const_obj_ptr;

    /*...*/
    template <typename T>
        requires std::is_object_v<T>
    constexpr explicit bound_entity_type(const T* ptr) noexcept
        : const_obj_ptr(ptr) {}
};
```
{: .nolineno}

As the last step, we also need to extend our `get` utility function to return the right pointer if a const object is requested:

```cpp
template <typename T>
constexpr static auto get(bound_entity_type entity) {
    if constexpr (std::is_const_v<T>) {
        return static_cast<T*>(entity.const_obj_ptr);
    } else {
        return static_cast<T*>(entity.obj_ptr);
    }
}
```
{: .nolineno}

Now we also support *const functors*. If you want to see the code for this part, here are the links: [cpp insights](https://cppinsights.io/s/0b116486), [compiler explorer](https://godbolt.org/z/5Kxfn1zqq).

## Support for pointers to functions

The next step is to add support for pointers to functions. This implementation will be a piece of cake compared to what we already have archived. The definition for the constructor we are interested in is as follows:

> `template<class F> function_ref(F* f) noexcept;`
>
> ***Constraints:***
> * `is_function_v<F>` is `true`, and 
> * *`is-invocable-using<F>`* is `true`.
> 
> ***Preconditions:*** `f` is not a null pointer.
>
> ***Effects:*** Initializes *`bound-entity`* with `f`, and *`thunk-ptr`* with the 
> address of a function *`thunk`* such that *`thunk(bound-entity, call-args...)`* 
> is expression-equivalent to `invoke_r<R>(f, call-args...)`.

Most of what we need to support this is already in place. We only need to extend our storage type again and implement the constructor. If we want to store a function pointer, we must define a proper storage type. The standard says the following about function pointers:

> A function pointer **can be explicitly converted to a function pointer of a 
> different type**. [...] Except that **converting** a prvalue of type “pointer to T1” 
> **to the type** “pointer to T2” (where T1 and T2 are function types) **and back to its 
> original type yields the original pointer value**, the result of such a pointer 
> conversion is unspecified. ([C++ Standard Draft N4849][7] section *7.6.1.9/6 [expr.reinterpret.cast]*)

Or [C++ reference][23] pharses it like:

> Any **pointer to function can be converted to a pointer to a different function 
> type**. Calling the function through a pointer to a different function type is 
> undefined, but **converting such pointer back** to pointer to the original function 
> type **yields the pointer to the original function**.

Based on these definitions, any function pointer type will do, and we can use a type as simple as `void(*)()`. Let us add this type to our `union`: 

```cpp
union bound_entity_type {
    /*...*/
    void (*fn_ptr)();

    /*...*/
    template <class T>
        requires std::is_function_v<T>
    constexpr explicit bound_entity_type(T* ptr) noexcept
        : fn_ptr(reinterpret_cast<decltype(fn_ptr)>(ptr)) {}
};
```
{: .nolineno}

We added the pointer type as `fn_ptr` to the internal representations and a dedicated constructor specialized for function types. To store 
the pointer in the constructor, we use an [`reinterpret_cast`][23] to the type of `fn_ptr` to benefit from the conversion guarantee for function pointers. 

Next, we add support for the function pointer to our `get` template function:

```cpp
template <typename T>
constexpr static auto get(bound_entity_type entity) {
    if constexpr (std::is_const_v<T>) {
        return static_cast<T*>(entity.const_obj_ptr);
    } else if constexpr (std::is_object_v<T>) {
        return static_cast<T*>(entity.obj_ptr);
    } else {
        return reinterpret_cast<T*>(entity.fn_ptr);
    }
}
```
{: .nolineno}

Now our storage is prepared. Next, we only need to implement the constructor. The implementation is straightforward:

```cpp
template <typename F>
    requires(std::is_function_v<F> && 
             is_invocable_using<F>)
function_ref(F* f) noexcept
: m_bound_entity{f}
, m_thunk_ptr{
    [](bound_entity_t entity, ARG_Ts... args) noexcept(noex) -> R {
      if constexpr (std::is_void_v<R>) {
          std::invoke(get<F>(entity), std::forward<ARG_Ts>(args)...);
      } else {
          return std::invoke(get<F>(entity), std::forward<ARG_Ts>(args)...);
      }
  }} 
{}
```
{: .nolineno}

We define the [requires clause][20] exactly like in the 
[proposal][2]. The member initialization is nearly the same as for our 
function objects. The only difference is that we already handle the right 
type, so we do not need anything *special* like `std::addressof` or *`cv`*. The last thing we need to add is the precondition. Because [`contracts`](https://wg21.link/p0542) didn't make it in the standard yet, we will use an assert for that: `assert(f != nullptr)`.[^7]

And that's it. Now we can handle function pointers:

```cpp
bool free_function1([[maybe_unused]] char) { return false; }
int free_function2() noexcept { return 3; }

function_ref<bool(char)> ff1{free_function1};
function_ref<int() noexcept> ff2{free_function2};

assert(!ff1('a'));
assert(ff2() == 3);
```
{: .nolineno}

You will find the code for this section under these links: 
[cpp insights](https://cppinsights.io/s/50561907), 
[compiler explorer](https://godbolt.org/z/b8n8h7bcx)

## Support for member methods and the `nontype<T>`

If we read the [proposal][2], we find in the *Wording* section the introduction of the tag type[^8] called `nontype`. This tag type is a ***generic non-type template object***. So it will be instantiated with a value known at compile time of any type, which can be used as a [non-type template argument][25]. To archive this, it uses the `auto` placeholder for non-types[^9]. Let us look at the implementation of `nontype` and then see what we can do with this:

```cpp
template <auto V>
struct nontype_t {
    explicit nontype_t() = default;
};

template <auto V>
constexpr nontype_t<V> nontype{};
```
{: .nolineno}

That is the complete implementation, but what can we do with this? The answer is simple, we can inject additional information at compile time and can do tag dispatching. Let us look at an example:

```cpp
template <std::integral T>
T generic_fn() { return {42}; }

template <auto fn_ptr>
constexpr int non_type_call(nontype_t<fn_ptr>) { return fn_ptr(); }

const auto val = non_type_call(nontype<generic_fn<int>>); 
assert(val == 42);
```
{: .nolineno}

In this example, we call a function pointer provided by the `nontype_t` parameter. The object construction `nontype<generic_fn<int>>` defines the template parameter for our `nontype` as the address of `generic_fn<int>` with the type `int(*)()`. So inside the function `non_type_call`, we use the function pointer (`fn_ptr`), provided as a template parameter, directly call it, and return the value. You can see in [cpp insights](https://cppinsights.io/s/0f29c9a6) what's going on:

```cpp
template<>
int generic_fn<int>() { return {42}; }

inline constexpr int non_type_call<&generic_fn>(nontype_t<&generic_fn>) {
  /* PASSED: static_assert(std::is_same_v<int (*)(), int (*)()>); */
  return &generic_fn();
}

const int val = non_type_call(nontype_t<&generic_fn>(nontype<&generic_fn>));
```
{: .nolineno}

This representation shows that our implementation creates nothing 
more than an indirection to `generic_fn`. Function pointers as non-type template parameters are a lovely old trick, which in the past archived outstanding performances in implementations like the [impossible fast delegate][26].

### Constructor for `nontype`

We can integrate this trick also in our `function_ref` implementation. The 
[proposal][2] already defines a constructor for this:

> `template<auto f> constexpr function_ref(nontype_t<f>) noexcept;`
> 
> Let `F` be `decltype(f)`.
> 
> ***Constraints:*** *`is-invocable-using<F>`* is `true`.
> 
> ***Mandates:*** If `is_pointer_v<F> || is_member_pointer_v<F>` is `true`, then `f != nullptr` is `true`.
> 
> ***Effects:*** Initializes `bound-entity` with a pointer to unspecified object or 
> null pointer value, and *`thunk-ptr`* with the address of a function *`thunk`* 
> such that *`thunk(bound-entity, call-args...)`* is expression-equivalent to 
> `invoke_r<R>(f, call-args...)`.

Let us start directly with the implementation. The declaration and the [requires clause][20] are straightforward; we can nearly directly use the [proposal][2] code:

```cpp
template <auto f>
  requires(is_invocable_using<decltype(f)>)
constexpr function_ref(nontype_t<f>) noexcept;
```
{: .nolineno}

The initialization is also relatively easy. We do not need to store any pointer, and we can use the default constructor for `m_bound_entity`. The only thing left is our lambda definition. Here we need to call the function pointer provided via `nontype`. The implementation looks like this:

```cpp
[](bound_entity_t entity, ARG_Ts... args) noexcept(noex) -> R {
    if constexpr (std::is_void_v<R>) {
        std::invoke(f, std::forward<ARG_Ts>(args)...);
    } else {
        return std::invoke(f, std::forward<ARG_Ts>(args)...);
    }
}
```
{: .nolineno}

The only thing that is missing is the *mandate* and we can enforce this 
via [`constexpr if`][27] and [`static_assert`][28]. If we put everything 
together our constructor looks like this:

```cpp
template <auto f>
  requires(is_invocable_using<decltype(f)>)
constexpr function_ref(nontype_t<f>) noexcept
  : m_bound_entity{}
  , m_thunk_ptr{
    [](bound_entity_t entity, ARG_Ts... args) noexcept(noex) -> R {
        if constexpr (std::is_void_v<R>) {
          std::invoke(f, std::forward<ARG_Ts>(args)...);
        } else {
            return std::invoke(f, std::forward<ARG_Ts>(args)...);
        }
    }} 
{
  using F = decltype(f);
  if constexpr (std::is_pointer_v<F> || std::is_member_pointer_v<F>) {
    static_assert(f != nullptr);
  }
}
```
{: .nolineno}

This constructor allows us now to use our `function_ref` with a `nontype` like in the `non_type_call` of the example earlier. So we can use it like this:

```cpp
function_ref<int()> nfn{nontype<generic_fn<int>>};
assert(nfn() == 42);
```
{: .nolineno}

Now all is done to support a `nontype` object. As usual, the source code is available on [compiler explorer](https://godbolt.org/z/sWGojGzEo) and [cpp insights](https://cppinsights.io/s/0d0c0702). 

Maybe you ask yourself why you should use `nontype` and not the constructor for the function pointer. The answer is `nontype` could be (slightly) faster, but mostly it will end up in the same assemble code. To check both versions, you can do so with [Quick C++ Bench](https://quick-bench.com/q/ffjch8vmQY4rMcYphlYDx_Es3EQ).

But the most exciting thing about this implementation is that the storage is unused for the `nontype` overload. So we can store additional information.

### Construction with member function pointers

If we use `nontype` to transfer the function address, we can use our storage to store the address to an object. This approach allows us to do calls to member functions. Let us look at how you can invoke member methods:

```cpp
struct my_class {
    char fn1([[maybe_unused]] bool) { return '3'; }
    int fn2() const { return 17; }
};

my_class obj{};
assert(std::invoke(&my_class::fn1, obj, false) == '3');

const my_class c_obj{};
assert(std::invoke(&my_class::fn2, c_obj) == 17);
```
{: .nolineno}

In this example, we invoke the member method by calling [`std::invoke`][29] with a reference to an object as the first parameter. If we store a pointer to this object in our `m_bound_entity` storage, we can make the same call with [`std::invoke`][29]. To do so, we need to implement an additional constructor, which is [propsed][2] like:

> `template<auto f, class U> constexpr function_ref(nontype_t<f>, U&& obj) noexcept;`
> 
> Let `T` be `remove_reference_t<U>` and `F` be `decltype(f).`
> 
> ***Constraints:***
> * `is_rvalue_reference_v<U&&>` is `false`,
> * *`is-invocable-using<F, cv T&>`* is `true`.
>
> ***Mandates:*** If `is_pointer_v<F> || is_member_pointer_v<F>` is `true`, then `f != nullptr` is `true`.
>
> ***Effects:*** Initializes *`bound-entity`* with `addressof(obj)`, and *`thunk-ptr`* 
> with the address of a function *`thunk`* such that *`thunk(bound-entity, call-args...)`* 
> is expression-equivalent to `invoke_r<R>(f, static_cast<cv T&>(obj), call-args...)`.

Implementing this feels like a hybrid between the *functor* and the `nontype` constructor. We start as usual with the declaration and the 
[require clause][20]:

```cpp
template <auto f, typename U, typename T = std::remove_reference_t<U>>
    requires(!std::is_rvalue_reference_v<U &&> &&
             is_invocable_using<decltype(f), cv<T>&>)
constexpr function_ref(nontype_t<f>, U&& obj) noexcept;
```
{: .nolineno}

The first *mandate* checks that nobody accidentally gives us a temporary object. The rest of the declaration is similar to the other constructors we have already done. The member initialization is also straightforward. We initialized the storage with the address of `obj`, and our lambda needs only to combine the address of the `nontype` with the `obj` stored in our `bound_entity_type`. With all in place, the constructor looks like this:

```cpp
template <auto f, typename U, typename T = std::remove_reference_t<U>>
    requires(!std::is_rvalue_reference_v<U &&> &&
             is_invocable_using<decltype(f), cv<T>&>)
constexpr function_ref(nontype_t<f>, U&& obj) noexcept
  : m_bound_entity{std::addressof(obj)}
  , m_thunk_ptr{
      [](bound_entity_t entity, ARG_Ts... args) noexcept(noex) -> R {
        cv<T>& obj = *get<T>(entity);
        if constexpr (std::is_void_v<R>) {
            std::invoke(f, obj, std::forward<ARG_Ts>(args)...);
        } else {
            return std::invoke(f, obj, std::forward<ARG_Ts>(args)...);
        }
    }} 
{
    using F = decltype(f);
    if constexpr (std::is_pointer_v<F> || std::is_member_pointer_v<F>) {
        static_assert(f != nullptr);
    }
}
```
{: .nolineno}

After the implementation of this constructor overload, we can now also create a `function_ref` with member methods:

```cpp
my_class obj{};
function_ref<char(bool)> mfn1{ nontype<&my_class::fn1>, obj };
assert(mfn1(false) == '3');

const my_class c_obj{};
function_ref<int() const> mfn2{ nontype<&my_class::fn2>, c_obj };
assert(mfn2() == 17);
```
{: .nolineno}

But we can do more. This constructor is not restricted to pointers of member methods. We can also bind values to functions:

```cpp
int free_function3(int val) noexcept { return val; }

const int val = 42;
function_ref<int() noexcept> ffn{ nontype<&free_function3>, val};
assert(ffn() == val);
```
{: .nolineno}

In this example, we bind `val` to `free_function3`, which allows us to call our `function_ref` without any parameters. If you want to play around to find out what else you can do with this constructor, you can do so in [compiler explorer](https://godbolt.org/z/cd9bc8GjY) or [cpp insights](https://cppinsights.io/s/42eebae4).

### Construction with an additional object pointer

There is only one constructor left to implement. The constructor's definition is as follows:

> `template<auto f, class T> constexpr function_ref(nontype_t<f>, cv T* obj) noexcept;`
> 
>  Let `F` be `decltype(f)`.
> 
> ***Constraints:*** 
> * `is-invocable-using<F, cv T* >` is `true`.
> 
> ***Mandates:*** If `is_pointer_v<F> || is_member_pointer_v<F>` is `true`, then `f != nullptr` is `true`.
> 
> ***Preconditions:*** If `is_member_pointer_v<F>` is `true`, obj is not a null pointer.
> 
> ***Effects:*** Initializes *`bound-entity`* with obj, and *`thunk-ptr`* with the address 
> of a function *`thunk`* such that *`thunk(bound-entity, call-args...)`* is 
> expression-equivalent to `invoke_r<R>(f, obj, call-args...)`.

This description is nearly identical to the previous constructor, only that we act directly on a pointer. The implementation looks like this:

```cpp
template <auto f, typename T>
    requires(is_invocable_using<decltype(f), cv<T>*>)
constexpr function_ref(nontype_t<f>, cv<T>* obj) noexcept
    : m_bound_entity{obj}
    , m_thunk_ptr{
        [](bound_entity_t entity, ARG_Ts... args) noexcept(noex) -> R {
            cv<T>* obj = get<cv<T>>(entity);
            if constexpr (std::is_void_v<R>) {
                std::invoke(f, obj, std::forward<ARG_Ts>(args)...);
            } else {
                return std::invoke(f, obj, std::forward<ARG_Ts>(args)...);
            }
      }} 
{
    using F = decltype(f);
    if constexpr (std::is_pointer_v<F> || std::is_member_pointer_v<F>) {
        static_assert(f != nullptr);
    }
    if constexpr (std::is_member_pointer_v<F>) {
        assert(obj != nullptr);
    }
}
```
{: .nolineno}

Now let us test our new constructor. To use it, we only need to provide an additional pointer to our `function_ref` construction:

```cpp
struct data {
    const int i = 182;
};

int free_function4(data* ptr) noexcept { return ptr->i; }

data d{};
function_ref<int()> pfn{nontype<&free_function4>, &d};
assert(pfn() == 182);
```
{: .nolineno}


But if we try this code, we get a compilation error because the compiler can not deduct `T` from `cv<T>*`. Our trait `cv_fn` creates the issue. In this trait, we define the constness, deduct the right type according to this information, and provide `T` in one step. To do this in one stage is too much for the compiler here, so we need to change our implementation for this trait. Let us introduce a new type trait called `cv_qualifier`. The difference will now be that we deduct the type in two steps. 
1. define the right specialization for the template based on the signature `SIG_T`
2. define the right type based on a provided `T`

The implementation looks like this:
```cpp
namespace detail {
template <typename SIG_T, bool is_const = is_const_fn_v<SIG_T>>
struct cv_qualifier {
    template <typename T>
    using cv = const T;
};

template <typename SIG_T>
struct cv_qualifier<SIG_T, false> {
    template <typename T>
    using cv = T;
};
}  // namespace detail
```
{: .nolineno}

We must use our new `cv_qualifier` trait instead of `cv_fn_t` inside our `function_ref` class. To do so, we need to replace: 

```cpp
template <typename T>
using cv = typename detail::cv_fn_t<SIG_T, T>;
```
{: .nolineno}

With the following lines:

```cpp
using cv_qualifier = detail::cv_qualifier<SIG_T>;

template <class T>
using cv = cv_qualifier::template cv<T>;
```
{: .nolineno}

Now everything builds and behaves as it should. And with this in place, we now have every constructor of the [proposal][2] implemented. You can look at what we have archived on [compiler explorer](https://godbolt.org/z/94nbbqeeP) or [cpp insights](https://cppinsights.io/s/1f28b8ea).

## Final Touch

Only some small final touches still need to be added to finish the class implementation. At first we need to delete `template<class T> function_ref& operator=(T)` this is defined as:

> `template<class T> function_ref& operator=(T) = delete;`
> 
> ***Constraints:***
> * `T` is not the same type as `function_ref`, and
> * `is_pointer_v<T>` is `false`, and
> * `T` is not a specialization of `nontype_t`

We can not implement the constraint for the `nontype_t` detection yet. So let us add a trait to detect `nontype`: 

```cpp
namespace detail {
template <typename>
struct is_nontype : std::false_type {};

template <auto f>
struct is_nontype<nontype_t<f>> : std::true_type {};

template <typename T>
inline constexpr bool is_nontype_v = is_nontype<T>::value;
}  // namespace detail
```
{: .nolineno}

Now we can delete the assignment operator:

```cpp
template <typename T>
    requires(!std::is_same_v<std::remove_cvref_t<T>, function_ref> &&
             !std::is_pointer_v<T> && !detail::is_nontype_v<T>)
function_ref& operator=(T) = delete;
```
{: .nolineno}

So this does not touch the assignment operator for `function_ref`, so we still fulfill `std::is_trivially_assignable`, but we can default our copy and assignment like the [proposal][2] list. We need to add these two lines to our class:

```cpp
constexpr function_ref(const function_ref&) noexcept = default;
constexpr function_ref& operator=(const function_ref&) noexcept = default;
```
{: .nolineno}

And now our class acts like it was proposed. The complete implementation is on [compiler explorer][30] and on [cpp insights][31] available. 

## Summary

In this post, we have implemented a complete `function_ref` class based on the proposal: [`function_ref: a type-erased callable reference`][2] and addressed the flaws in the [previous implementation][1]. We only need to add the [template deduction guides][32], but we will address them later.

**To sum it up:** Implementing a `function_ref` class is more complex than it seems, but it is still doable and a good exercise.

## References

### Blogs

* [Vittorio Romeo][3]: [passing functions to functions](https://vittorioromeo.info/index/blog/passing_functions_to_functions.html)
* [Foonathan][4]: [Implementing `function_view` is harder than you might think][5]

### Paper 

* N4849: [Working Draft, Standard for Programming Language C++][7]
* P0792: [`function_ref: a type-erased callable reference`][2]

### Code

* [zhihaoy/nontype_functional@p0792r13][6] complete implementation of `function_ref`


## Footnotes

[^1]: You can find the example in compiler explorer: [https://godbolt.org/z/saobbPhPz](https://godbolt.org/z/saobbPhPz) 
[^2]: In this post, we will focus on revision 14 of [P0792][2]
[^3]: This definition is from [C++ reference][10]
[^4]: Macros would also be an option, but I'm unwilling to implement them because they are way too "ugly".
[^5]: To avoid [object slicing][12], the base class needs to have a virtual or protected destructor.
[^6]: We also add an [alias][15] for `bound_entity_type` because we maybe will move it to a different scope later.
[^7]: We could also add *contracts lite* by using the [GSL](https://github.com/microsoft/GSL), which would also give us access to `not_null<T>`, but this is out of scope for this post.
[^8]: If you want to know more about tag types and tag dispatching, I recommend: [How to Use Tag Dispatching In Your Code Effectively](https://www.fluentcpp.com/2018/04/27/tag-dispatching/)
[^9]: The `auto` placeholder was introduced with C++17. If you want to know more about this, you can read the proposal: [P0127 Declaring non-type template parameters with `auto`][24]

[1]: {% post_url 2023-08-03-type-erasure-function-ref%}
[2]: https://wg21.link/p0792r14
[3]: https://vittorioromeo.info/index.html 
[4]: https://www.foonathan.net/
[5]: https://www.foonathan.net/2017/01/function-ref-implementation/
[6]: https://github.com/zhihaoy/nontype_functional/blob/p0792r13/include/std23/function_ref.h
[7]: https://wg21.link/n4849
[8]: https://en.cppreference.com/w/cpp/language/partial_specialization
[9]: https://en.cppreference.com/w/cpp/named_req/FunctionObject
[10]: https://en.cppreference.com/w/cpp/named_req/Callable
[11]: https://en.cppreference.com/w/cpp/utility/functional
[12]: https://en.wikipedia.org/wiki/Object_slicing
[13]: https://en.cppreference.com/w/cpp/language/classes#Trivial_class
[14]: https://learn.microsoft.com/en-us/cpp/cpp/trivial-standard-layout-and-pod-types?view=msvc-170#standard-layout-types
[15]: https://en.cppreference.com/w/cpp/language/type_alias
[16]: https://en.cppreference.com/w/cpp/language/adl
[17]: https://en.cppreference.com/w/cpp/types/integral_constant
[18]: https://en.cppreference.com/w/cpp/types/is_trivially_copyable
[19]: https://en.cppreference.com/w/cpp/language/static_assert
[20]: https://en.cppreference.com/w/cpp/language/requires
[21]: https://en.cppreference.com/w/cpp/memory/addressof
[22]: {% post_url 2023-07-29-type-erasure-nonowning%}
[23]: https://en.cppreference.com/w/cpp/language/reinterpret_cast
[24]: https://wg21.link/p0127r2
[25]: https://en.cppreference.com/w/cpp/language/template_parameters
[26]: https://www.codeproject.com/articles/11015/the-impossibly-fast-c-delegates
[27]: https://en.cppreference.com/w/cpp/language/if
[28]: https://en.cppreference.com/w/cpp/language/static_assert
[29]: https://en.cppreference.com/w/cpp/utility/functional/invoke
[30]: https://godbolt.org/z/G59YzWG8z
[31]: https://cppinsights.io/s/b696ed55
[32]: https://en.cppreference.com/w/cpp/language/class_template_argument_deduction
