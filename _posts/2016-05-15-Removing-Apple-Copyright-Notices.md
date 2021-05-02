---
layout: post
title:  "Removing Long and Annoying Apple Copyright Headers"
date:   2016-05-15 21:35:12
published: true
---

Apple provides a lot of sample iOS projects that are a great way to get started
learning a new topic. But one HUGE annoyance is the 50 lines or so at the start
of each file that is legal boilerplate that gets in the way when trying to read
the code. Having to scroll down 50 lines for each file to get to something good
is to too much work for a lazy developer like me.

To get around this, I wrote this bash one-liner that will go through all
objective-c files in the project and removes all comments from the top
of the file.

{% highlight sh %}
gfind . -iregex ".+\.[hm]$" -type f -exec gawk -i inplace '!f&&/\*\//{f=1;next}f' "{}" ";"
{% endhighlight %}

This assumes you have the GNU versions of `find` and `awk` installed as `gfind`
and `gawk`, respectively.  If not you can install them with `brew` like so:


{% highlight sh %}
brew install gawk
brew install coreutils
{% endhighlight %}

To see the before and after, check out this [commit](https://github.com/idrisr/iosSampleAppPhotoLocations/commit/8a1ce9c71ce00c72dc8baa62280915bd5711efc2). All copyright boilerplate gone in seconds!

For an explanation of the `gawk` magic in that line, check out this Stack
Overflow [post](https://stackoverflow.com/questions/34968109/remove-first-multiline-comment-from-file).

I hope it doesn't need to be said that just because we are deleting the
copyright headers that it has any bearing on the actual copyright. I'm not a
lawyer, but just saying.
