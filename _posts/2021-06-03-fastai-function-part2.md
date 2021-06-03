---
toc: True
title: fastai and python decorators, Part 2
---


```python
from torch import nn
from fastcore.all import *
import inspect
```


```python
%load_ext autoreload
%autoreload 2
```

    The autoreload extension is already loaded. To reload it, use:
      %reload_ext autoreload


In part one, I looked at decorators, decorators with arguments, and emphasized that decorators don't need to return functions. Decorators can return any object, and that's the object that will be bound to the name of the decorated function. This is important as we continue looking at the function in question.


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
                for i,o in enumerate(args): kwargs[all_flds[i]] = o
                kwargs = merge(defaults,kwargs)
                for k,v in kwargs.items(): setattr(self,k,v)
            __repr__ = basic_repr(all_flds)
            forward = f
        c.__signature__ = inspect.Signature(params)
        c.__name__ = c.__qualname__ = f.__name__
        c.__doc__  = f.__doc__
        return c
    return _f
```

`module` is being used as decorator that takes an argument - so the outermost callable `module` takes arguments from the decorator, the middle callable `_f` accepts the decorated function, and the return value of `_f` is what is bound to the name of the decorated function. Remember that the most common use of decorators is to wrap other functions, but that's not the only use. The name of the decorated function will be bound to the return value, and that doesn't have to be a function! In this case it's `class c`! Make sure you understand this point!

Now that we have a handle on the mechanics of what is going on, let's look at why this structure is useful.  I don't know *alot* about Pytorch, so keep that in mind for the rest of the discussion.  PyTorch uses `nn.Module` as nodes in the computation graph for the neural net, and if you want to define your own you need to subclass `nn.Module` and then define the `forward` method which will operate on the data input to the node in the forward pass. The backward pass will be handled by autograd... I think. That's a subject for another day after some deeper discovery.

The essential idea is that we only need to define the  `__init__` and  `forward` functions for the custom module, and that's exactly what this decorator affords us. The function being decorated will become the `forward` function, and that happens from this line:

```python
forward = f
```

The full signature is `forward(self, x)`, and that's exactly the signature of all the functions being decorated by `@module`.  

## Fun with the `inspect` module

The next thing to notice is how the decorator arguments are used. They are used to create saved state for the inner function `_f`, and specifically they're used to create the `__signature__` attribute of `class c` via the `params` variable, and to create the list of fields required as arguments for `c.__init__` via `all_flds`. I'll let you figure out the exact mechanics, but the bottom line is that the decorator arguments are used to create the `__signature__` object for `__init__`  and to create a list of the required arguments for the `__init__` while storing the default arguments. Read more about the [`inspect`](https://docs.python.org/3/library/inspect.html) module and the [function signature object](https://www.python.org/dev/peps/pep-0362/#:~:text=Python%20has%20always%20supported%20powerful,fully%20reconstruct%20the%20function's%20signature)

## In Conclusion


This is one hell of a function! Per my count of advanced python features we have

1. decorators

2. decorators with arguments

3. function signature objects

4. function parameter creation via `inspect.Parameter`

5. dynamic class creation

6. functions as first class citizens via `forward = f`
    
    
I'm pretty happy that I took the time to dissect what the heck this function was doing. I hope this post shed some light on it for you and then you're inspired to go read some source code and learn the more advanced parts of a language when you encounter something novel.
