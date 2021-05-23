---
toc: True
title: fastai and python decorators, Part 1
---

For the fast few weeks I've been learning the [fastai](https://github.com/fastai/fastai) deep learning framework by trying examples and reading the source code. The source code is dense, meaning there's a lot of ideas packed into a small number of lines, and it is using the python language in ways I'm not totally familiar with. Python decorators are used heavily, and while I thought I understood python decorators, I came across this function and realized I didn't know enough. This blog post is about exploring python decorators, and then using that knowledge to dissect and understand the following function.


```python
def module(*flds, **defaults):
    "Decorator to create an `nn.Module` using `f` as `forward` method"
    pa = [inspect.Parameter(o, inspect.Parameter.POSITIONAL_OR_KEYWORD) for o in flds]
    pb = [inspect.Parameter(k, inspect.Parameter.POSITIONAL_OR_KEYWORD, default=v)
          for k,v in defaults.items()]
    params = pa+pb
    all_flds = [*flds,*defaults.keys()]
    
    def _f(f):
        class c(nn.Module):
            def __init__(self, *args, **kwargs):
                super().__init__()
                print(f"kwargs before: {kwargs}")
                for i,o in enumerate(args): kwargs[all_flds[i]] = o
                kwargs = merge(defaults,kwargs)
                print(f"kwargs after: {kwargs}")
                for k,v in kwargs.items(): setattr(self,k,v)
            __repr__ = basic_repr(all_flds)
            forward = f
        c.__signature__ = inspect.Signature(params)
        c.__name__ = c.__qualname__ = f.__name__
        c.__doc__  = f.__doc__
        return c
    return _f
```

First let's start with the simplest of decorators:

## Decorators with no Arguments


```python
def f(a):
    print("in f")
    def _f():
        print("in _f")
        a()
    return _f

@f
def g():
    print("in g")
```

    in f


The thing to notice is that `f` is executed when the code is parsed. No functions were directly called, but `in f` was printed. Any function that acts as a decorator will be called immediately. That's the first thing to know.


```python
g()
```

    in _f
    in g


The next thing to know is that the name `g` will be bound to whatever is returned from the decorator function `f`. In this case we're returning the inner function `_f`. This is the most common pattern, but it doesn't need to be. We can return anything from the decorator function.


```python
def f(a):
    print("in f")
    return "something"
```


```python
@f
def g():
    print("in g")
```

    in f



```python
g # print value of g
```




    'something'



In this case we pass `g` into `f`, but then `f` doesn't do anything with `g` and just returns a string.  This is not very common, as it doesn't achieve much, but just realize that the name `g` will be bound to whatever is returned from `f`. The original function `g` is lost, because it's not used in `f` and the name `g` is now associated with the string returned from `f`.

## Decorator With Arguments

Sometimes we want to pass arguments into the decorator function. This changes things, and is what most confused me at first. Here we add a second nested function. Notice that the outermost function `f` accepts the arguments from the decorator, the middle function `g` accepts the function being decorated, and the innermost function `h` is what is bound to the name of the decorated function `y`. It's like a series of nested dolls. Also notice that the two outermost functions `f` and `g` are executed immediately.


```python
def f(a, b):
    print("f")
    def g(c):
        print("g")
        def h():
            print("h")
        return h
    return g
```


```python
@f(1, 2)
def y():
    print("y")
```

    f
    g



```python
y()
```

    h


## Callables, not functions

Now let's look at an example using a class as the decorator instead of a function. In the above explanations I've been using the word function to explain what's going on, but that wasn't quite correct. I should have been saying callable instead of function. Class `C` is callable. When called it will execute the `__init__` function and return an instance of class `C`. Notice that `C.__init__` is called as soon as the decorator is parsed, just like the functions above used as decorators. `f` is now bound to an instane of `C`, and we can call the member function `do_f`.


```python
class C:
    def __init__(self, f):
        print("in init")
        self.f = f
    
    def do_f(self):
        self.f()
```


```python
@C
def f():
    print("in f")
```

    in init



```python
f.do_f()
```

    in f


## Class decorators with arguments

Now we're going to pass an argument to the callable. Remember from the example with a function decorator with arguments that there were two inner functions, and the innermost one was bound to the name of the decorated function. This example is exactly parallel, expect now we're using a class. You can consider the outermost function to be `__init__`, and middle function to be `__call__`, and the name of the decorated function will be replaced by whatever is returned from `__call__`. Typically a function is returned, but that is not a requirement. Also notice that `__init__` and `__call__` are called immediately.


```python
class D:
    def __init__(self, a):
        print("in init")
        self.a = a
        print(f"a={self.a}")
    
    def __call__(self, f):
        print("in call")
        return f
```


```python
@D(1)
def f(a):
    print("in f")
    print(f"arg={a}")
```

    in init
    a=1
    in call



```python
f(10)
```

    in f
    arg=10


In part two, we're going to look at this pattern of a decorator with arguments is used in fastai!
