---
title:  "Debugging a Debugger"
date:   2015-10-12 21:35:12
published: true
toc: true
---

[LLDB](http://lldb.llvm.org/) is the debugger that ships automatically with XCode. Everyhing you can do with LLDB is also available through a Python API so you can write python code to programmatically debug anything that you write using XCode, including C, Objective-C, Swift, and C++.

It's a really powerful way to debug as you can automate much of the debugging process and do things that aren't practical without scripting.

With this power comes a downside - you're now writing code to debug code. What if your debugging code has a bug? Into the abyss we go...

The Facebook dev team has created the
[chisel](https://github.com/facebook/chisel) library which bundles tools to
solve common debugging tasks. Chisel can be installed as a single python package with [homebrew](http://brew.sh/) like `brew install chisel`.

Chisel offers a LLDB function called `wivar` which sets the watchpoint on an object's instance variable like so `wivar self _number`.
This same functionality is offered by XCode's debug GUI, so I'd expect that either method would create the a watchpoint watching the same memory address.

___
## El Bug de Debug

As you can see from the gif below, the XCode gui and the `wivar self _number` cause different results. If the commands were both equivalent, which they should be, they'd show the same memory address in the `new value` field.  There was an existing github issue on this bug so I had assurance it wasn't just me so I decided to dig in.

![cat gif](http://i.giphy.com/xTiTnz7bNkagGeCGg8.gif)

---
## LLDB with Python, quickly

First a very quick overview on how to add custom LLDB commands. LLDB allows you to create your own custom debug commands with any script that calls into the LLDB API, though currently only Python is supported. For example you create a python module with the following functions:

{% highlight py linenos=table %}
#!/usr/bin/env python
# filename: my_lldb_module.py

def hello_command(debugger, command, result, internal_dict):
    """ This command provides a greeting """
    print "Hello Command"

def __lldb_init_module(debugger, internal_dict):
    debugger.HandleCommand('command script add -f my_lldb_module.hello_command hello')
{% endhighlight %}

and then you can load the command into an lldb session like so:

{% highlight sh linenos=table %}
 $ lldb
(lldb) command script list
For more information on any command, type 'help <command-name>'.
(lldb) command script import my_lldb_module.py
(lldb) command script list
Current user-defined commands:

  hello -- For more information run 'help hello'

For more information on any command, type 'help <command-name>'.
(lldb) help hello
 This command provides a greeting

Syntax: hello
(lldb) hello
Hello Command
(lldb)
{% endhighlight %}

---
## Chisel and `wivar`

The `chisel` library is effectively doing this for a few dozen commands, one of which is the `wivar` command.

The meat of the command is the following:

{% highlight py linenos=table %}
    def run(self, arguments, options):
        commandForObject, ivarName = arguments

        objectAddress = int(fb.evaluateObjectExpression(commandForObject), 0)

        ivarOffsetCommand = '(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id){}, "{}", 0))'.format(objectAddress, ivarName)
        ivarOffset = fb.evaluateIntegerExpression(ivarOffsetCommand)

        # A multi-statement command allows for variables scoped to the command, not permanent in the session like $variables.
        ivarSizeCommand = ('unsigned int size = 0;'
                           'char *typeEncoding = (char *)ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id){}), "{}"));'
                           '(char *)NSGetSizeAndAlignment(typeEncoding, &size, 0);'
                           'size').format(objectAddress, ivarName)
        ivarSize = int(fb.evaluateExpression(ivarSizeCommand), 0)

        error = lldb.SBError()
        watchpoint = lldb.debugger.GetSelectedTarget().WatchAddress(objectAddress + ivarOffset, ivarSize, False, True, error)

        if error.Success():
            print 'Remember to delete the watchpoint using: watchpoint delete {}'.format(watchpoint.GetID())
        else:
            print 'Could not create the watchpoint: {}'.format(error.GetCString())
{% endhighlight sh %}

Essentially what this function does is threefold:

1. find the memory address of the object
2. find the difference in bytes between the address of the object and the [`Ivar`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/#//apple_ref/c/tdef/Ivar), a C struct, that contains our instance variable
3. determine the type encoding of the instance variable to get its memory size

To undestand what's going on here you have to parse those objective-c commands that are being invoked, which is a segue to start understanding the objective-c runtime.

---
## Fun with the Objective-C runtime

It took me a while to understand what was happening here, including reading the [Objective-C runtime guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html), (ps - if you're writing Obj-C, do yourself a favor and read it).

---
### 1. Get the address of the object
{% highlight py %}
    objectAddress = int(fb.evaluateObjectExpression(commandForObject), 0)
{% endhighlight %}

which ultimately resolves to create this objective-c command
{% highlight objc %}
    (id)(0x00007f8663633380)
{% endhighlight %}

where `0x00007f8663633380` is the address determined in the previous step.

You can use lldb to show that this address be accessed multiple ways, including
using the name of the instance, and different forms of the numerical address of
the memory location:

{% highlight objc linenos=table %}
(lldb) p (id)(self)
(ViewController *) $1 = 0x00007f8663633380
(lldb) p self
(ViewController *) $2 = 0x00007f8663633380
(lldb) p/t self
(ViewController *) $3 = 0b0000000000000000011111111000011001100011011000110011001110000000
(lldb) p/o self
(ViewController *) $4 = 03770314330631600
(lldb) p/d self
(ViewController *) $5 = 140215169790848
(lldb) p/x self
(ViewController *) $6 = 0x00007f8663633380
(lldb) po 0b0000000000000000011111111000011001100011011000110011001110000000
<ViewController: 0x7f8663633380>

(lldb) po 03770314330631600
<ViewController: 0x7f8663633380>

(lldb) po 140215169790848
<ViewController: 0x7f8663633380>

(lldb) po 0x00007f8663633380
<ViewController: 0x7f8663633380>

(lldb)
{% endhighlight %}

---
### 2. Get the memory offset of the `Ivar`

{% highlight py linenos=table %}
ivarOffsetCommand = '(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id){}, "{}", 0))'.format(objectAddress, ivarName)
ivarOffset = fb.evaluateIntegerExpression(ivarOffsetCommand)
{% endhighlight %}

This command is a bit more involved so I'm going to unpack it to its simpler
parts. After this command is formatted with its string substituations it looks
like this objective-c command:

{% highlight objc linenos=table %}
(int)((ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0)))

# cast the memory address to be an object
(id)140215169790848

# get the value of the instance variable `_number`
object_getInstanceVariable((id)140215169790848, "_number", 0)

# cast the return value to be any generic pointer. Note this is a C call, not Obj-C
(void *)object_getInstanceVariable((id)140215169790848, "_number", 0)

# Get the offset in bytes of the Ivar opaque type from its object's starting address
ivar_getOffset((void *)object_getInstanceVariable((id)140215169790848, "_number", 0))

# Cast the difference in bytes to a ptrdiff_t. not strictly necessary, but doesn't hurt
(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))

# Cast the ptrdiff_t to an int
(int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))
{% endhighlight %}

You can run each of these commands in lldb in a breakpoint and see what's going
on:

{% highlight objc linenos=table %}
(lldb) po (id)140215169790848
<ViewController: 0x7f8663633380>

(lldb) po object_getInstanceVariable((id)140215169790848, "_number", 0)
0x0000000104ffc5a0

(lldb) po (void *)object_getInstanceVariable((id)140215169790848, "_number", 0)
0x0000000104ffc5a0

(lldb) po ivar_getOffset((void *)object_getInstanceVariable((id)140215169790848,
"_number", 0))
0x0000000000000300

(lldb) po (ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))
768

(lldb) po (int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))
768
{% endhighlight %}

Now we know that the offset for the instance variable we want to watch is 768 bytes from the address of its object.

---
### 3. Get the size in bytes of the instance variable

We need to konw the full size of the instance variable so we can watch that full
memory chunk for changes.

That is what this multi-line statement does.


{% highlight py linenos=table %}
ivarSizeCommand = ('unsigned int size = 0;'
               'char *typeEncoding = (char *)ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id){}), "{}"));'
               '(char *)NSGetSizeAndAlignment(typeEncoding, &size, 0);'
               'size').format(objectAddress, ivarName)
ivarSize = int(fb.evaluateExpression(ivarSizeCommand), 0)
{% endhighlight %}

There a a few things going on here, so I'll unpack them one statement at a time.

{% highlight objc linenos=table %}

# declare a var to hold the number of bytes the ivar uses
unsigned int size = 0;

# get the class of the object whose instane variable we want to watch
object_getClass((id)140215169790848);

# cast the object to type Class
(Class)object_getClass((id)140215169790848);

# get a reference to the instance variable we're interested in
class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number");

# cast the return value to be a generic pointer
(void *)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number");

# get a reference to the type encoding of the instance variable we're interested in
ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number"));

# cast the reference to be a C string
(char *)ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number"));

# save the type encoding
char *typeEncoding = (char *)ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number"));

# figure out how many bytes typeEncoding requires, and save it into &size
(char *)NSGetSizeAndAlignment(typeEncoding, &size, 0);

# return the value of size as the final statement of the multi-line statement;
size

# The end result after string substitution:
unsigned int size = 0; char *typeEncoding = (char *)ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number")); (char *)NSGetSizeAndAlignment(typeEncoding, &size, 0); size
{% endhighlight %}

We can execute all of the commands in a running lldb session with a breakpoint set at a place where `self` resolves to the object we're interested in.

{% highlight objc linenos=table %}
(lldb) e unsigned int size = 0;
(lldb) p object_getClass((id)140215169790848);
error: 'object_getClass' has unknown return type; cast the call to its declared return type
error: 1 errors parsing expression
(lldb) p (Class)object_getClass((id)140215169790848);
(Class) $1 = ViewController
(lldb) p class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number");
error: 'class_getInstanceVariable' has unknown return type; cast the call to its declared return type
error: 1 errors parsing expression
(lldb) p (void *)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number");
(void *) $2 = 0x0000000104ffc5a0
(lldb) p ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number"));
error: 'ivar_getTypeEncoding' has unknown return type; cast the call to its declared return type
error: 1 errors parsing expression
(lldb) p (char *)ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number"));
(char *) $3 = 0x0000000104fdf656 "@\"NSNumber\""
(lldb) e unsigned int size = 0; char *typeEncoding = (char *)ivar_getTypeEncoding((void*)class_getInstanceVariable((Class)object_getClass((id)140215169790848), "_number")); (char *)NSGetSizeAndAlignment(typeEncoding, &size, 0); size
(unsigned int) $4 = 8
{% endhighlight %}

And so after all that, we see that the `_number` takes up 8 bytes.

---
### Putting it all together

To recap, we needed three things to programmatically set the watchpoint for an object's instance variable. Those 3 things are:

| Description | Variable | Value |
| --- | --- | ---: |
| 1. The address of the object | `objectAddress` | 140215169790848 |
| 2. The offset number of bytes from the object's Ivar | `ivarOffset` | 768 |
| 3. The size in bytes of the instance variable | `ivarSize` | 8 |

We've got all three of things now, so we should be able to call into the LLDB Python API like so to set the watchpoint:

{% highlight py linenos=table %}
error = lldb.SBError()
watchpoint = lldb.debugger.GetSelectedTarget().WatchAddress(objectAddress + ivarOffset, ivarSize, False, True, error)

if error.Success():
    print 'Remember to delete the watchpoint using: watchpoint delete {}'.format(watchpoint.GetID())
else:
    print 'Could not create the watchpoint: {}'.format(error.GetCString())
{% endhighlight %}

This is the current state, as shown in the git at the start of this post, so we know something is wrong. Most likely we are calculating the one of three values used in the `WatchAddress()` function incorrectly.


---
### Summary Objective-C runtime and helper functions used
| Command | Description |
| --- | :--- |
| [`ptrdiff_t`](https://www.gnu.org/software/libc/manual/html_node/Important-Data-Types.html) | memory size difference between pointers |
[`ivar_getOffset`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/#//apple_ref/c/func/ivar_getOffset) | Returns the offset of an instance variable.
[`object_getInstanceVariable`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/#//apple_ref/c/func/object_getInstanceVariable) | Obtains the value of an instance variable of a class instance.
[`ivar_getTypeEncoding`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/#//apple_ref/c/func/ivar_getTypeEncoding) | Returns the type string of an instance variable.
| [`class_getInstanceVariable`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/#//apple_ref/c/func/class_getInstanceVariable) | Returns the Ivar for a specified instance variable of a given class.
| [`object_getClass`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/#//apple_ref/c/func/object_getClass) | Returns the class of an object.
| [`NSGetSizeAndAlignment`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Functions/#//apple_ref/c/func/NSGetSizeAndAlignment) | Obtains the actual size and the aligned size of an encoded type.
| [`WatchAddress`](http://lldb.llvm.org/python_reference/lldb.SBTarget-class.html) | Sets the watchpoint address based on starting address and size

---

## Chisel Helper Functions

The way to directly invoke an objective-c expression from a python interperter in LLDB looks something like this:

{% highlight py linenos=table %}
def evaluateExpressionValueWithLanguage(expression, language, printErrors):
    frame = lldb.debugger.GetSelectedTarget().GetProcess().GetSelectedThread().GetSelectedFrame()
    expr_options = lldb.SBExpressionOptions()
    expr_options.SetLanguage(language)  # requires lldb r210874 (2014-06-13) / Xcode 6
    value = frame.EvaluateExpression(expression, expr_options)
    if printErrors and value.GetError() is not None and str(value.GetError()) != 'success':
        print value.GetError()
    return value
{% endhighlight %}

Here we are digging down from the target to the process to the thread and finally to a particular stack frame. In this stack frame context we can evaluate different expressions. Instead of repeating this over and over, the chisel library encapsulates these functions into a set of helper functions, which all eventually call the chunk of code above.

In the code we reviewed above, we call 3 different version of these helper functions: `evaluateIntegerExpression`, `evaluateExpression`, and `evaluateObjectExpression`.

{% highlight py linenos=table %}
def evaluateIntegerExpression(expression, printErrors=True):
    output = evaluateExpression('(int)(' + expression + ')', printErrors).replace('\'', '')
    if output.startswith('\\x'): # Booleans may display as \x01 (Hex)
        output = output[2:]
    elif output.startswith('\\'): # Or as \0 (Dec)
        output = output[1:]
    return int(output, 16)

def evaluateExpression(expression, printErrors=True):
    print(expression)
    return evaluateExpressionValue(expression, printErrors).GetValue()

def evaluateObjectExpression(expression, printErrors=True):
    return evaluateExpression('(id)(' + expression + ')', printErrors)
{% endhighlight %}

The bug is somewhere above. Can you find it? Clue: It's in `evaluateIntegerExpression`.

___
## De(nouement)bug

This simple bug took hours to find, as the easiest bugs are the most subtle, especially when you're looking for hard bugs.

The problem is in `return int(output, 16)`. The python `int` functions's docstring is:

{% highlight py linenos=table %}
In [1]: int?
Docstring:
int(x=0) -> int or long
int(x, base=10) -> int or long

Convert a number or string to an integer, or return 0 if no arguments
are given.  If x is floating point, the conversion truncates towards zero.
If x is outside the integer range, the function returns a long instead.

If x is not a number or if base is given, then x must be a string or
Unicode object representing an integer literal in the given base.  The
literal can be preceded by '+' or '-' and be surrounded by whitespace.
The base defaults to 10.  Valid bases are 0 and 2-36.  Base 0 means to
interpret the base from the string as an integer literal.
>>> int('0b100', base=0)
4
Type:      type
{% endhighlight %}

You can pass an int or a an integer literal and define the base. In the above code, we're telling `int` that the base is base16. But that's a problem, as we will use a base16 value in our calculations with base10 values.

Recall from above that we used this command to determine the value of the `Ivar` offset:
{% highlight py linenos=table %}
(int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))
{% endhighlight %}

I'll run that command directly in LLDB, and then again after getting in a Python interpreter from LLDB.

{% highlight py linenos=table %}
(lldb) e (int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))
(int) $1 = 768
(lldb) script
Python Interactive Interpreter. To exit, type 'quit()', 'exit()' or Ctrl-D.
>>> import fblldbbase
>>> fblldbbase.evaluateIntegerExpression('(int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))')
(int)((int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0)))
1896
>>> fblldbbase.evaluateExpression('(int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))')
(int)(ptrdiff_t)ivar_getOffset((void*)object_getInstanceVariable((id)140215169790848, "_number", 0))
'768'
>>> int('768', 16)
1896
>>>
(lldb)
{% endhighlight %}

Now the issue should be clear. We have the right objective-C expression to get the size of the offset, but then we mess it up by telling python that the number should be converted to base16 while it should stay in base10.

___
## Resolution

Now that the bug is found after a lot of digging, the solution is trivial. You can see the pull request [here](https://github.com/facebook/chisel/pull/122).

Comments and discussion on Hacker News [here](https://news.ycombinator.com/item?id=10447054).
