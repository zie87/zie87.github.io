---
layout: post
title: 'Classic C++: Compile-Time Type Lists'
date: '2023-10-14 15:30:00'
categories: ['C++', 'Classic C++']
tags: ['c++', 'classic', 'type traits', 'meta programming', 'type sequence']
---


Some time ago, I mentioned that I needed to work on a legacy code base stuck 
with C++98. I must include some alternatives for features working with the 
old standard, especially for [variadic template parameters][2]. Luckily, there 
is at least an alternative for [type_sequences][1]: ***cons style typelists***[^1].


## The Typelist Type

A typelist is essential, like the name suggests, a list of types.  It's a 
recursive compile-time data structure similar to a linked list of types, where 
each node contains a type and a reference to the next node. The definition of 
this node looks like this:

```cpp
struct nil_type {};

template <typename HEAD_T, typename TAIL_T = nil_type>
struct typelist {
  typedef HEAD_T head_type;
  typedef TAIL_T tail_type;
};
```

This node allows the creation of a series by nesting the template structures. 
The end of a `typelist` is marked with the `tail_type` being a `nil_type`. 
Such a list definition can look like this:

```cpp
typedef typelist<int, typelist<char, typelist<float> > > list_type;
```


Admittedly, this `typedef` is not the most pleasant code. The "manual" 
definition of a `typelist` is quite repetitive and difficult to grasp by the 
reader of the code. But there are some solutions for this. The [Loki library][10] 
provides a set of macros to reduce this effort. Such macros can be defined like this:

```cpp
#define TYPELIST_1(t1) typelist<t1, nil_type>
#define TYPELIST_2(t1, t2) typelist<t1, TYPELIST_1(t2) >
#define TYPELIST_3(t1, t2, t3) typelist<t1, TYPELIST_2(t2, t3) >

typedef TYPELIST_3(int, char, float) list_type;
```

I prefer to create my `typelist` via *maker templates*. Such a *maker* works 
similarly to the factory method. For this approach, we must define a meta-function 
with a reasonable number of template parameters. 

```cpp
template <typename T01 = nil_type, typename T02 = nil_type, typename T03 = nil_type, typename T04 = nil_type,
          typename T05 = nil_type, typename T06 = nil_type, typename T07 = nil_type, typename T08 = nil_type,
          typename T09 = nil_type, typename T10 = nil_type, typename T11 = nil_type, typename T12 = nil_type,
          typename T13 = nil_type, typename T14 = nil_type, typename T15 = nil_type, typename T16 = nil_type,
          typename T17 = nil_type, typename T18 = nil_type, typename T19 = nil_type, typename T20 = nil_type>
struct make_typelist {
private:
    typedef typename make_typelist<T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18,
                                   T19, T20>::type tail_type;

public:
    typedef typelist<T01, tail_type> type;
};
```

All parameters need to be defaulted to `nil_type`, and the creation will then be 
repeated via recursion until no none `nil_type` is left. This stop condition 
can look like this:

```cpp
template <>
struct make_typelist<> {
    typedef nil_type type;
};
```

The usage of `make_typelist` looks like the following:

```cpp
typedef typename make_typelist<int, char, float>::type list_type;
```

## Calculating the Size

This kind of `typelist` is a recursive data structure. So, a template recursion 
can solve nearly all operations on this structure. The size calculation is a 
good example of this. At first, we need to declare the template metafunction:

```cpp
template <typename>
struct size;
```

Now we need to specialize this function for our typelist and start the counting. 
To count the objects, we make a recursive call to our metafunction for the tail 
and increase the return value by one:

```cpp
template <typename HEAD_T, typename TAIL_T>
struct size<typelist<HEAD_T, TAIL_T> > {
    static const int value = 1 + size<TAIL_T>::value;
};
```

The last step is the specialization for the stop condition of the recursion. 
The recursion should stop when the tail is a `nil_type`. This condition will 
return zero. The implementation looks like this:

```cpp
template <>
struct size<nil_type> {
    static const int value = 0;
};
```

The meta function is used via: `size<list_type>::value`, which will return the 
number of elements (recursions) as a compile-time constant.

The check for emptiness can be done with `size<list_type>::value == 0`.
An alternative implementation is also possible, which avoids the recursion. 
A type list is empty if it equals the `nil_type`. 
This implementation for an empty looks like this:

```cpp
template <typename>
struct empty;

template <>
struct empty<nil_type> {
    static const bool value = true;
};

template <typename HEAD_T, typename TAIL_T>
struct empty<typelist<HEAD_T, TAIL_T> >  {
    static const bool value = false;
};
```

## Indexed Access

To access a specific type in the `typelist` by index, a new meta function is needed:

```cpp
template <typename T, int INDEX_V>
struct at;
```

To implement this meta function for a `typelist`, we need to navigate through the list until we reach the desired index:

```cpp
template <typename HEAD_T, typename TAIL_T, int INDEX_V>
struct at<typelist<HEAD_T, TAIL_T>, INDEX_V> {
    typedef typename at<TAIL_T, (INDEX_V - 1)>::type type;
};

template <typename HEAD_T, typename TAIL_T>
struct at<typelist<HEAD_T, TAIL_T>, 0> {
    typedef HEAD_T type;
};
```

The first meta function is the specialization for the `typelist`. This 
specialization calls itself recursively and reduces the index with each recursion. 
The stop condition is reached when the index has the value zero. The detection 
of the condition is implemented via template specialization. This specialization 
will return the head type, so we found the type at the index.

This code allows access to an element in the list by its index with a call 
like: `typename at<list_type, 3>::type`. But this implementation is not safe 
against misuse. An out-of-bounds index will end up in an infinite recursion. 
This misbehavior can be prevented with [static assertions][3][^2] and 
additional overloads. 

## Search in the List

### contains

Often, it is needed to check if a specific type or property is in the typelist. 
This check can be implemented as a meta function, which recursively traverses 
the list and checks each type if it matches with the given type.  

The meta function and the recursion look like this:

```cpp
template <typename, typename>
struct contains;

template <typename HEAD_T, typename TAIL_T, typename T>
struct contains<typelist<HEAD_T, TAIL_T>, T> {
    static const bool value = contains<TAIL_T, T>::value;
};
```

The recursion should stop if the head of the list matches the given type. 
This condition is implemented via template specialization:

```cpp
template <typename TAIL_T, typename T>
struct contains<typelist<T, TAIL_T>, T> {
    static const bool value = true;
};
```

If the list does not contain the type, the recursion must stop, and the meta 
function must return `false`. The check is done with a specialization 
for `nil_type`:

```cpp
template <typename T>
struct contains<nil_type, T> {
    static const bool value = false;
};
```

### index of

We can follow a similar approach to find the specific index of a type within a 
typelist. We need to define a meta function which traverses the list until we 
find the given type:

```cpp
template <typename, typename>
struct index_of;

template <typename HEAD_T, typename TAIL_T, typename T>
struct index_of<typelist<HEAD_T, TAIL_T>, T> {
    static const int value = 1 + index_of<TAIL_T, T>::value;
};

template <typename TAIL_T, typename T>
struct index_of<typelist<T, TAIL_T>, T> {
    static const bool value = 0;
};
```

To get the index of the type, we increase the counter (`value`) by one with 
each recursion, as we have done for the size calculation. When we find the 
type, we set `value` to zero and stop the recursion.

Some implementations, for example [Loki´s Typelist][10], would also specialize 
for the `nil_type` and return a negative value in this case. I prefer an 
  upfront check if the list contains the type inside a [static assertions][3] 
  to stop the compiling directly.  

## Extend the List

### push front

The easiest way to extend a type list is with a `push_front` meta function. 
The `push_front` operation for a typelist means creating a new typelist with 
the desired type as a head and the other list as a tail. The implementation 
looks like this:

```cpp
template <typename, typename>
struct push_front;

template <typename HEAD_T, typename TAIL_T, typename T>
struct push_front<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<T, typelist<HEAD_T, TAIL_T> > type;
};
```

There is also a special case to consider for the empty list. This operation 
would create a new list directly, with the desired type as head:

```cpp
template <typename T>
struct push_front<nil_type, T> {
    typedef typelist<T> type;
};
```

### push back

Often, a `push_back` is preferred over a `push_front`. To implement a `push_back`, 
a meta function is needed which traverses the list recursively until it reaches 
the end:

```cpp
template <typename, typename>
struct push_back;

template <typename HEAD_T, typename TAIL_T, typename T>
struct push_back<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<HEAD_T, typename push_back<TAIL_T, T>::type> type;
};
```

The stop condition is again a specialization for the `nil_type`. This 
specialization would do the same as for the `push_front` operation:

```cpp
template <typename T>
struct push_back<nil_type, T> {
    typedef typelist<T> type;
};
```

The `nil_type` specialization will return a new typelist. This typelist has the 
desired type as a head.

### append

Another operation to extend a type list is appending all types of another list. 
Most of the implementation is the same as for the `push_back` meta function:

```cpp
template <typename, typename>
struct append;

template <typename HEAD_T, typename TAIL_T, typename T>
struct append<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<HEAD_T, typename append<TAIL_T, T>::type> type;
};

template <typename T>
struct append<nil_type, T> {
    typedef typelist<T> type;
};

```

The only difference is that an additional specialization is needed if the new 
type is also a `typelist`. In this case, we want to integrate the list and 
not define it as `head_type`. The implementation can look like this:

```cpp
template <typename HEAD_T, typename TAIL_T>
struct append<nil_type, typelist<HEAD_T, TAIL_T> > {
    typedef typelist<HEAD_T, TAIL_T> type;
};
```

## Remove from a List

### remove first

To remove the first occurrence of a type from the list, we need to search for 
the type similar to what we have done for `contains` or `index_of`:

```cpp
template <typename, typename>
struct remove_first;

template <typename HEAD_T, typename TAIL_T, typename T>
struct remove_first<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<HEAD_T, typename remove_first<TAIL_T, T>::type> type;
};
```

As soon as we have found the type, we only need to return the tail without the 
undesired type:

```cpp
template <typename T, typename TAIL_T>
struct remove_first<typelist<T, TAIL_T>, T> {
    typedef TAIL_T type;
};
```

The last step is the specialization for `nil_type`. If the recursion reaches 
the `nil_type`, the undesired type is not in the list. In this case, the meta 
function can return `nil_type` again, and the operation will not alter the 
input list:

```cpp
template <typename T, typename TAIL_T>
struct remove_first<typelist<T, TAIL_T>, T> {
    typedef TAIL_T type;
};
```

### remove all

If we want to remove all occurrences instead, we must define a new meta 
function, `remove`. This function is, for the most part, nearly identical 
to `remove_first`:

```cpp
template <typename, typename>
struct remove;

template <typename HEAD_T, typename TAIL_T, typename T>
struct remove<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<HEAD_T, typename remove<TAIL_T, T>::type> type;
};

template <typename T>
struct remove<nil_type, T> {
    typedef nil_type type;
};
```

The only difference is in the specialization for the matching type. If we find 
the type, we can not stop anymore. We must continue the recursion until we 
reach the end of the list:

```cpp
template <typename T, typename TAIL_T>
struct remove<typelist<T, TAIL_T>, T> {
    typedef typename remove<TAIL_T, T>::type type;
};
```

## Replace Elements in the List

### replace first

If you want to replace a type instead of removing it from the list, you can do 
this with a similar implementation. We need a meta function that traverses the 
list via recursion. The only difference is that we now need also a template 
parameter for our new desired type:

```cpp
template <typename, typename, typename>
struct replace_first;

template <typename HEAD_T, typename TAIL_T, typename T, typename U>
struct replace_first<typelist<HEAD_T, TAIL_T>, T, U> {
    typedef typelist<HEAD_T, typename replace_first<TAIL_T, T, U>::type> type;
};
```

If we can not find the type and we reach the end of the list, we do not need to 
do anything special:

```cpp
template <typename T, typename U>
struct replace_first<nil_type, T, U> {
    typedef nil_type type;
};
```

The last specialization we need is if the match is detected. If we have a match, 
we need to return a new typelist with the desired type (`U`) as head instead 
of the undesired type (`T`): 

```cpp
template <typename T, typename TAIL_T, typename U>
struct replace_first<typelist<T, TAIL_T>, T, U> {
    typedef typelist<U, TAIL_T> type;
};
```

### replace all

This implementation will replace the first occurrence of a type in the `typelist`. 
If you want to replace all occurrences instead, we can similarly do this. For 
the most part, the meta function is nearly identical:

```cpp
template <typename, typename, typename>
struct replace_first;

template <typename HEAD_T, typename TAIL_T, typename T, typename U>
struct replace_first<typelist<HEAD_T, TAIL_T>, T, U> {
    typedef typelist<HEAD_T, typename replace_first<TAIL_T, T, U>::type> type;
};

template <typename T, typename U>
struct replace_first<nil_type, T, U> {
    typedef nil_type type;
};
```

As for `remove`, the only difference is that we can not stop on the match 
specialization. So this specialization needs to continue the recursion also 
after we replaced the head:

```cpp
template <typename T, typename TAIL_T, typename U>
struct replace<typelist<T, TAIL_T>, T, U> {
    typedef typelist<U, typename replace<TAIL_T, T, U>::type> type;
};
```


## Summary

Typelists are a handy tool that allows you to act on an unspecific set of types 
in classic C++. Most operations on typelist can be implemented with minimal 
effort, simply by using meta functions with template recursion. 

This post shows some of the essential meta functions to operate on typelists. 
If you want to try the complete code, you can do so in 
[compiler explorer](https://godbolt.org/z/M6fdEsYha).

## References

### Books

* Andrei Alexandrescu: *Modern C++ Design - Generic Programming and Design Pattern Applied* (2000)
* David Vandervoorde: *C++ Templates - The Complete Guide* (2003)
* David Vandervoorde: *C++ Templates - The Complete Guide* (2018)

### Libraries

* [zll][4] a library created by myself, which contains a typelist implementation
* [Loki][10] provides this functionality as `Typelist`

## Footnotes

[^1]: It is called cons style because they are modeled after LISP´s `cons` cells.
[^2]: I explained in a previous [post][3] how you could implement a static assertion for C++98.

[1]: {% post_url 2023-05-27-type-sequence%}
[2]: https://en.cppreference.com/w/cpp/language/parameter_pack
[3]: {% post_url 2023-06-11-static-assertions%}
[4]: https://github.com/zie87/zll
[10]: https://loki-lib.sourceforge.net/

