---
title:  "Improving LLDB's backtrace to be more like GDB's full backtrace"
date:   2016-05-29 21:35:12
published: true
toc: true
---

[LLDB](http://lldb.llvm.org/) is a big step up from [GDB](https://www.gnu.org/software/gdb/), but some of the default behavior of GDB is better than LLDB.

One example of this is the `backtrace` or `bt` command. In GDB, `backtrace` 1) prints all
of the frames in the stack trace, and 2) it also prints all the frame variables in
the each of the frames. LLDB only prints all of the frames in the stack trace,
while excluding the frame variables. While you can print the frame variables
for a stack frame in lldb with `frame variable`, you have to select each frame
individually and then the print the frame variables, which is a
[PITA](https://www.urbandictionary.com/define.php?term=pita).

Luckily LLDB allows for the definition of custom commands and the use of
Python scripting to make this happen.  We can make an improved `bt` command for
use in LLDB and make it emulate the behavior of `bt` in GDB.

To do this, we creat the python function `full_backtrace` to iterate through all of the frames on
the current thread and print the name of each frame and its variables.

{% highlight python %}
# filename ~/lldb/lldb_custom.py

def full_backtrace(debugger, command, result, internal_dict):
    """gdb style backtrace full

    gdb's backtrace command also shows the frame variables for each stack
    frame, while lldb only shows the frame index, without the frame variables.
    This function emulates the more verbose gdb backtrace which shows the frame
    index and each index's frame variables.
    """

    target = lldb.debugger.GetSelectedTarget()
    thread = target.GetProcess().GetSelectedThread()
    print(thread)
    for frame in thread:
        print("%s" % frame)
        for variable in frame.variables:
            print("\t%s" % variable)

{% endhighlight %}

Next we map the function to a command name, in this case I chose `gbt`.

{% highlight python %}
# filename ~/lldb/lldb_custom.py
def __lldb_init_module(debugger, internal_dict):
    """required function to import module to lldb"""
    debugger.HandleCommand('command script add -f lldb_custom.full_backtrace gbt')
{% endhighlight %}

Lastly we need to import this script in our `~/.lldbinit` file which XCode will
read automatically.

{% highlight sh %}
# filename ~/.lldbinit
command script import /Users/id/lldb/lldb_custom.py
{% endhighlight %}

Now that it's all hooked up, we can see how it can be far more helpful than the
default `bt` command, or the default display XCode shows in the Debug
Navigator. If you have a bunch of functions all calling each other, it's very
helpful to see each frame's variables all at once and without doing a bunch of
work.

![original image](http://i.imgur.com/3xegyyi.png)
