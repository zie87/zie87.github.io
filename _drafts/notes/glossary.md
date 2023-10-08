## CRTP: Curiously Recurring Template Pattern

CRTP is a C++ idiom, where a class/struct (`my_struct`) derives from a class 
template (`template_base`) instantiantion using itself as a template parameter.

```cpp
template <typename DERVICED_T>
struct template_base {
  using derived_type = DERVICED_T;

private:
  derviced_type& derived() noexcept {
    return static_cast<derived_type&>(*this);
  }

  const derviced_type& derived() const noexcept {
    return static_cast<const derived_type&>(*this);
  }
};

struct my_struct : template_base<my_struct> {};
```

The inheritence make the casts in line 7 and 11 safe and allows to extend 
the interface of `my_struct` based on the implementations in `template_base`.

### References:

Jason Turner: C++ Weekly 259 ["CRTP: What It Is, Some History and Some Uses"](https://youtu.be/ZQ-8laAr9Dg)
