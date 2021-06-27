---
toc: True
title: Python Descriptors
published: False
---

# Python Descriptor

* allegedly the key to understanding Python

## Primer


```python
class Ten:
    def __get__(self, obj, objtype=None):
        return 10
```


```python
class A:
    x = 5 # regular class attribute
    y = Ten() # Descriptor instance
```


```python
Ten().__get__(None)
```




    10




```python
a = A()
a.x
```




    5




```python
a.y # Descriptor Lookup
```




    10



## Dynamic Lookups

interesting descriptors typically run computations instead of returning constants


```python
import os

class DirectorySize:
    def __get__(self, obj, objtype=None):
        return len(os.listdir(obj.dirname))
    
class Directory:
    size = DirectorySize()
    def __init__(self, dirname):
        self.dirname = dirname
```


```python
s = Directory(os.getenv("HOME"))
s.size
```




    195




```python
g = Directory(os.getenv("HOME") + '/.fastai')
g.size
```




    4



## Managed Attributes

* descriptor is assigned to a public attribute in the class dictionary
* actual data is stored as a private attribute in instance dictionary
* `__get__` and `__set__` triggered when public attribute is accessed


```python
import logging
logging.basicConfig(level=logging.INFO)
```


```python
class LoggedAge:
    def __get__(self, obj, objtype=None):
        logging.info("Accessing %r with value %r", obj.name, obj._age)
        return obj._age

    def __set__(self, obj, objtype=None):
        obj._age = objtype
        logging.info("Setting %r with value %r", obj.name, obj._age)
    
    
class Person:
    age = LoggedAge()
    
    def __init__(self, name, age):
        self.name = name
        self.age = age
        
    def birthday(self):
        self.age += 1
```


```python
vars(LoggedAge)
```




    mappingproxy({'__module__': '__main__',
                  '__get__': <function __main__.LoggedAge.__get__(self, obj, objtype=None)>,
                  '__set__': <function __main__.LoggedAge.__set__(self, obj, objtype=None)>,
                  '__dict__': <attribute '__dict__' of 'LoggedAge' objects>,
                  '__weakref__': <attribute '__weakref__' of 'LoggedAge' objects>,
                  '__doc__': None})




```python
mary = Person('Mary M', 30)
```

    INFO:root:Setting 'Mary M' with value 30



```python
dave = Person('David D', 40)
```

    INFO:root:Setting 'David D' with value 40



```python
vars(mary)
```




    {'name': 'Mary M', '_age': 30}




```python
vars(dave)
```




    {'name': 'David D', '_age': 40}




```python
mary.age
```

    INFO:root:Accessing 'Mary M' with value 30





    30




```python
dave.birthday()
```

    INFO:root:Accessing 'David D' with value 40
    INFO:root:Setting 'David D' with value 41



```python
dave.age = 42
```

    INFO:root:Setting 'David D' with value 42



```python
vars(dave)
```




    {'name': 'David D', '_age': 42}



## Customized names
* the above example has the the name `_age` hardcoded making it unavailable for reuse
* this can be fixed


```python
import logging
logging.basicConfig(level=logging.INFO)

class LoggedAccess:
    def __set_name__(self, owner, name):
        self.public_name = name
        self.private_name = '_' + name
    
    def __get__(self, obj, objtype=None):
        value = getattr(obj, self.private_name)
        logging.info('Accessing %r giving %r', self.public_name, value)
        return value
    
    def __set__(self, obj, value):
        logging.info('Updating %r to %r', self.public_name, value)
        setattr(obj, self.private_name, value)
```


```python
class Dog:
    
    def __init__(self, name, age):
        pass
```


```python
Dog.mro()
```




    [__main__.Dog, object]




```python
class A:pass
class B: pass
class C(A): pass
class D(C, B): pass
class E(A, B): pass
E.mro()
```




    [__main__.E, __main__.A, __main__.B, object]




```python
__name__
```




    '__main__'




```python

```
