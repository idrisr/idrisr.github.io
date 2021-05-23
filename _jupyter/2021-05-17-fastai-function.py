def module():
    def _f(f):
        class c:...
        return c
    return _f


@module()
def Identity(self, x):
    return x


@module()
def Lambda(self, x):
    return self.func(x)

def Lambda2(self, x):
    return self.func(x)

def g():
    class c:...
    return c

Bro = module()(g)
Lambda2=module()(Lambda2)

def a():
    b=1
    c=2
    d=3
