---
layout: post
title: 'Classic C++: Compile-Time Type Lists'
date: '2023-10-10 12:01:32'
categories: ['C++', 'Classic C++']
tags: ['c++', 'classic', 'type traits', 'meta programming', 'type sequence']
---

Some time ago I mentioned that I need to work on a legacy code base which is 
stuck with C++98. After some time work with the old standard I start to miss 
some features, especially [variadic template parameters][2]. Luckely there is 
at least an alternative for [type_sequences][1]: ***cons style typelists***[^1].


## The Typelist Type

A typelist is essentially, like the name suggest, a list of types. 
It's a recursive compile-time data structure that can be thought of as a linked list of 
types, where each node contains a type and a reference to the next node. The 
defintion of this node looks like this:

```cpp
struct nil_type {};

template <typename HEAD_T, typename TAIL_T = nil_type>
struct typelist {
  typedef HEAD_T head_type;
  typedef TAIL_T tail_type;
};
```

This node allows to create a series by nesting the template structures. The end 
of a `typelist` is marked with the `tail_type` being a `nil_type`. Such a list 
defintion can look like this:

```cpp
typedef typelist<int, typelist<char, typelist<float> > > list_type;
```


Admittedly this `typedef` is not the most pleasend code to look at. The 
"manual" definition of a `typelist` is quite repetative and not easy to grasp 
by the reader of the code. But there are some solutions for this. The 
[Loki library][10] provides a set of macros to reduce this effort. Such macros 
can be defined like this:

```cpp
#define TYPELIST_1(t1) typelist<t1, nil_type>
#define TYPELIST_2(t1, t2) typelist<t1, TYPELIST_1(t2) >
#define TYPELIST_3(t1, t2, t3) typelist<t1, TYPELIST_2(t2, t3) >

typedef TYPELIST_3(int, char, float) list_type;
```

I personally prefer to create my `typelist` via *maker templates*. Such *maker* 
works similar to factory methode. For this approach a meta function needs to be 
defined with reasonable set of parameters. 

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

All parameters need to be defaulted to `nil_type` and the creation will than be 
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

We also need to define a trait for our list to use it for feature 
specialisation. The trait overload is straight forward. The default trait is 
defined as `false`. This trait is than specialised for `typelist` and 
`nil_type`, who will define the trait as `true` instead. The implementation 
could look like the following:

```cpp
template <typename>
struct is_typelist {
    static const bool value = false;
};

template <typename HEAD_T, typename TAIL_T>
struct is_typelist<typelist<HEAD_T, TAIL_T> > {
    static const bool value = true;
};

template <>
struct is_typelist<nil_type> {
    static const bool value = true;
};
```

With this code in place we can start to implement some algorithms for the 
`typelist`. You can find the code for the implementations so far at 
[compiler explorer](https://godbolt.org/z/6ehY5E7rn).

## Calculating the Size

This kind of `typelist` is a recursive data structure. So nearly all operations 
on this structure can be solved via template recursion. The size calculation is 
a good example for this. At frist we need to declare the template metafunction:

```cpp
template <typename>
struct size;
```

Now we need to specialize this function for our typelist and start the counting.
To count the objects we make a recursive call to our metafunction for the tail 
and increase the return value be one:

```cpp
template <typename HEAD_T, typename TAIL_T>
struct size<typelist<HEAD_T, TAIL_T> > {
    static const int value = 1 + size<TAIL_T>::value;
};
```

The last step is the specialisation for the stop condition of the recursion. The 
recursion should stop as soon as the tail is a `nil_type`. This condition will 
return zero and can be implemented like this:

```cpp
template <>
struct size<nil_type> {
    static const int value = 0;
};
```

The meta function is called via: `size<list_type>::value`, which will 
return the number of elements (recursions) as a compile time constant.

To check for emptyness it is possible to check for `size<list_type>::value == 0`,
but there is also a implementation possible, which avoids the recursion. A 
type list is empty if it equals the `nil_type`. This is a possible implement 
for a check like this:

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

To access a specific type in the `typelist` by index, a new meta function is 
needed:

```cpp
template <typename T, int INDEX_V>
struct at;
```

To implement this meta function for a `typelist`, we need to navigate trough 
the list until we reach the desired index:

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

The first meta function is the specialisation for the `typelist`. This 
specialisation calls it self recursivly and reduces the index with each 
recursion. The stop condition is reached when the index has the value zero. This 
is also dected via template specialisation. This specialisation will return 
the head type and so we found the type at the index.

This code allows to access an element in the list by its index with a 
call like: `typename at<list_type, 3>::type`. But this implementation is not 
safe against missuse. An out of bounds index will end up in an infinit recursion. 
This can be prevented with [static assertions][3][^2] and additional overloads. 

## Search in the List

### contains

Often it is needed to check if a certian type or property is in the typelist. 
This check can be implemented as a meta function, which recursevly traverses 
the list and checks each type if it matches with the given type.  

The meta function and the recursion looks like this:

```cpp
template <typename, typename>
struct contains;

template <typename HEAD_T, typename TAIL_T, typename T>
struct contains<typelist<HEAD_T, TAIL_T>, T> {
    static const bool value = contains<TAIL_T, T>::value;
};
```

The recursion should stop if the head of the list matches the given type. This 
is implemented via template specialisation:

```cpp
template <typename TAIL_T, typename T>
struct contains<typelist<T, TAIL_T>, T> {
    static const bool value = true;
};
```

If the list does not contain the type the recursion needs to stop and the meta 
function needs to return `false`. This can be checked with a specialisation for 
`nil_type`:

```cpp
template <typename T>
struct contains<nil_type, T> {
    static const bool value = false;
};
```

### index of

To find the specific index of a type within a typelist, we can follow a similar 
approach. We need to define a meta function which traverses the list until the 
given type is found:

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

The get the index of the type we increase the counter (`value`) by one with each 
recursion, like we have done for the size calcualtion. When we found the type 
we set `value` to zero and stop the recursion.

Some implementation like for example [Loki´s Typelist][10] would also specialise 
for the `nil_type` and return a negative value in this case. I 
personally prefer an upfront check, if the list containes the type. Such check 
can then be used in a [static assertions][3] to stop the compiling directly.  

## Extend the List

### push front

The easist way to extend a type list is with a `push_front` meta function. The 
`push_front` operation in the typelist, means that we need to create a new 
typelist, which has the desired type as head and the other list as tail. The 
implementationm looks like this:

```cpp
template <typename, typename>
struct push_front;

template <typename HEAD_T, typename TAIL_T, typename T>
struct push_front<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<T, typelist<HEAD_T, TAIL_T> > type;
};
```

There is also the special case to consider for the empty list. This operation 
would create a new list directly, with the desired type as head:

```cpp
template <typename T>
struct push_front<nil_type, T> {
    typedef typelist<T> type;
};
```

### push back

Often a `push_back` is prefered over a `push_front`. To implement a `push_back` 
a meta function is needed which traveres the list recursivly until it reaches 
the end:

```cpp
template <typename, typename>
struct push_back;

template <typename HEAD_T, typename TAIL_T, typename T>
struct push_back<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<HEAD_T, typename push_back<TAIL_T, T>::type> type;
};
```

The stop condition is again a specialisation for the `nil_type`. This 
specialisation would do exactly the same like for the `push_front` operation:

```cpp
template <typename T>
struct push_back<nil_type, T> {
    typedef typelist<T> type;
};
```

As soon as the `nil_type` is reached it will now return a new typelist which 
then is include as the tail of the given list.

### append

A other operation to extend a type list is by appending all types of another 
list. The most part of the implementation is the same like for the `push_back` 
meta function:
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

The only difference is that an additional specialisation is needed, if the new 
type is also a `typelist`. In this case we want to integrate the list and not 
define it as `head_type`. This can look like this:

```cpp
template <typename HEAD_T, typename TAIL_T>
struct append<nil_type, typelist<HEAD_T, TAIL_T> > {
    typedef typelist<HEAD_T, TAIL_T> type;
};
```

## Remove from a List

### remove first

To remove the first occurance of a type from the list we need to search for the 
type similar like what we have done for `contains` or `index_of`:

```cpp
template <typename, typename>
struct remove_first;

template <typename HEAD_T, typename TAIL_T, typename T>
struct remove_first<typelist<HEAD_T, TAIL_T>, T> {
    typedef typelist<HEAD_T, typename remove_first<TAIL_T, T>::type> type;
};
```

As soon as we have found the type we only need to return the tail without the 
undesired type:

```cpp
template <typename T, typename TAIL_T>
struct remove_first<typelist<T, TAIL_T>, T> {
    typedef TAIL_T type;
};
```

The last step is the specialication for `nil_type`. If the recursion reaches 
the `nil_type`, means that the undesired type is not part of the list. In this 
case the meta function can simply return `nil_type` again and the input list 
will not be altered:

```cpp
template <typename T, typename TAIL_T>
struct remove_first<typelist<T, TAIL_T>, T> {
    typedef TAIL_T type;
};
```

### remove all

If we want to remove all occurances instead, we need to define a new meta 
function `remove`. This function is for the most parts nearly identical to `remove_first`:

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

The only difference is in the specialisation for the matching type. 
If the type is found we can not stop anymore. The recursion needs to be 
continued until the end of the list is reached:

```cpp
template <typename T, typename TAIL_T>
struct remove<typelist<T, TAIL_T>, T> {
    typedef typename remove<TAIL_T, T>::type type;
};
```

## Replace Elements in the List

### replace first

If you want to replace a type instead of removing it from the list, you can do 
this with a similar implementation. We need again a meta function, which 
traverses the list via recursion, the only difference is that we now need also 
a template parameter for our new desired type:

```cpp
template <typename, typename, typename>
struct replace_first;

template <typename HEAD_T, typename TAIL_T, typename T, typename U>
struct replace_first<typelist<HEAD_T, TAIL_T>, T, U> {
    typedef typelist<HEAD_T, typename replace_first<TAIL_T, T, U>::type> type;
};
```

If the type is not found and we reach the end of the list we do not need to do 
anything special:

```cpp
template <typename T, typename U>
struct replace_first<nil_type, T, U> {
    typedef nil_type type;
};
```

The last specialisation we need is if the match is detected. If we have a match 
we need to return a new typelist with the desired type (`U`) as head instead of the 
undesired type (`T`): 

```cpp
template <typename T, typename TAIL_T, typename U>
struct replace_first<typelist<T, TAIL_T>, T, U> {
    typedef typelist<U, TAIL_T> type;
};
```

### replace all

This implementation will replace the first occurance of a type in the `typelist`.
If you want to replace all occurances instead, we can do this in a similar way. 
For the most parts the meta function is nearly identical:

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

Like for `remove` the only difference is that we can not stop on the match 
specialisation. So this specialisation needs to continue the recursion also 
after the head is replaced:

```cpp
template <typename T, typename TAIL_T, typename U>
struct replace<typelist<T, TAIL_T>, T, U> {
    typedef typelist<U, typename replace<TAIL_T, T, U>::type> type;
};
```


## Summary

Typelists are a very useful tool, which gives you the possiblity to act on a 
unspecific set of types also in classic C++. Most operations on typelist can be 
implemented with a minimal amount of effort, simply by using meta functions with 
template recursion. This post shows some of the basic meta functions to operate 
on typelists. If you want to try the complete code, you can do so in 
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

[^1]: It is called cons style, because they are modeled after LISP´s `cons` cells.
[^2]: I explained in a previous [post][3] how you could implement a static assertion for C++98.

[1]: {% post_url 2023-05-27-type-sequence%}
[2]: https://en.cppreference.com/w/cpp/language/parameter_pack
[3]: {% post_url 2023-06-11-static-assertions%}
[4]: https://github.com/zie87/zll
[10]: https://loki-lib.sourceforge.net/

