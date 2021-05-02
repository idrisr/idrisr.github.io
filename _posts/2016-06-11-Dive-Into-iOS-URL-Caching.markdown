---
layout: post
title:  "Part 1. Network Caching and iOS"
date:   2016-06-11 21:35:12
published: true
---

All but the most trivial apps use some sort of network resource. That means sending bytes through a WiFi or cellular connection, usually to some server deep in the bowels of a data center. The difference between accessing data on a network and accessing local data on disk or memory can be as much as 200 times slower. See [here](http://norvig.com/21-days.html#answers) if you don't believe me.

As important as the network resources are, we must stay aware of how much
slower they are relative to local resources. One very fruitful avenue of
speed-up is by [caching](https://en.wikipedia.org/wiki/Cache_(computing))
remotely fetched resources and reusing them when possible.

iOS makes it pretty easy to do this, considering that [`NSURLRequest`](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/URLLoadingSystem/Concepts/CachePolicies.html#//apple_ref/doc/uid/20001843-BAJEAIEE)'s (assuming you're `Foundation` classes and not a networking library like
[AlamoFire](https://github.com/Alamofire/Alamofire) or [AFNetworking](https://github.com/AFNetworking)) default behavior is to cache responses.

This was my understanding until I started trying to use the cache at which point I got into some weeds.
  
## BackStory
I was connecting to the [NASA Photo of the
Day](https://api.nasa.gov/api.html#apod) API which serves a different
photo and metadata each day, going back to the mid 1990s. It's a free API and
you can get as many API keys as you want. That abundance is balanced by the
stingy 1000 requests per API Key per hour. There are over (365 days * 20 years) photos, so
it's paramount to preserve requests considering how few we have relative to
total.

## Problem

As I tested my app, I quickly ran out of my hourly quota. At first I thought
it was because I was going over 1000 requests, but it turned out I was
making the same requests over and over. This was contrary to my understanding
that `NSURLSession` would automatically cache all request-response pairs.

## Investigation

To see a fuller picture of what's going on, we need some tools.
___
# Tool 1: `curl`

Type the following command into your terminal of choice. We are asking for the
headers of the HTTP Response that is returned after accessing the webpage
you're looking at now.  We get back key-value pairs that tell us about the
state of the resource. For example, we see that the content is of type `text/html`, it's
`7816` bytes long, some date information, etc. A
full discussion of all the fields can be read
[here](https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) or
[here](https://en.wikipedia.org/wiki/List_of_HTTP_header_fields).

{% highlight sh %}
curl -I http://idrisr.com/2016/06/11/Dive-Into-iOS-URL-Caching.html
{% endhighlight %}

{% highlight sh %}
HTTP/1.1 200 OK 
Connection: keep-alive
Last-Modified: Sat, 11 Jun 2016 19:58:00 GMT
Content-Length: 7816
Content-Type: text/html
Server: WEBrick/1.3.1 (Ruby/2.2.3/2015-08-18)
Date: Sat, 11 Jun 2016 19:59:12 GMT
Via: 1.1 vegur
{% endhighlight %}

Doing the same thing for a NASA photo of the day url, we see a different set
of header fields

{% highlight sh %}
curl -I https://api.nasa.gov/planetary/apod?api_key=ZBrv2wKXCEGK34TQx21taIwI8nfxAQrdLWLpJ8to&date=2015-05-19
{% endhighlight %}

{% highlight sh %}
HTTP/1.1 200 OK
Age: 0
Content-Length: 1192
Content-Type: application/json
Date: Sat, 11 Jun 2016 20:28:23 GMT
Server: openresty
Vary: Accept-Encoding
Vary: Accept-Encoding
Via: 1.1 vegur, http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])
X-Cache: MISS
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 997
Connection: keep-alive
{% endhighlight %}

Go ahead and run that same curl command multiple times. You'll notice that the
field `X-RateLimit-Remaining` is decreasing. It's the counter the
server is using to measure how many requests you have left in the hour.

This sets up a convenient way to test our iOS caching. If
`X-RateLimit-Remaining` stays steady, we're using the cache. If it goes down,
we're not. By caching, we prevent the server from deducting a request
from our hourly allowance.

To test this out I wrote this [quick app](https://github.com/idrisr/caching)
which hits the NASA photo of the day server with requests for each day in May
and displays the results in a `UICollectionView`. 

Each cell shows the date request in blue, and the value of
`X-RateLimit-Remaining` for each response in black.

![cat gif](http://i.giphy.com/l46CrQWsn8k5MqhSo.gif)

We can see that the number of remaining api requests is decreasing, yet we are
submitting the same requests over and over, meaning we are not using the cache.
But iOS is supposed to cache for us "for free", right?!?

Well it's more complicated. There are HTTP headers the server uses to
communicate cache policy to the client.  If the content on the server has its
own reasons for doing so, it won't want the client to cache the response. 

The `Cache-Control` header field is needed in the server's response field for
iOS to cache the data. If the server is telling you not to cache the
data, don't unless you have a good reason. From our previous `curl` output, we
see that the `Cache-Control` header field is not present in the response from
the server, and it's why the cache isn't working yet.

___
# Tool 2: [Charles Proxy](https://www.charlesproxy.com/)

Charles is "web debugging proxy application" that well, lets us debug web
connections by using a proxy application. 

For example, we can intercept all the calls going to and from the server and
our app.

Because the we are making `https` calls to the server, we need to first install
Charles' SSL certificate on our machine so the simulator will trust responses
redirected through Charles.  Go to `Help -> SSL Proxying -> Install Charles
Root Certificate in iOS Simulators` and follow the KeyChain instructions.

![Install SSL Proxy](http://i.imgur.com/ZctkBEZ.png)

Now that we have Charles' SSL certificate installed in KeyChain, we must tell
it to intercept the HTTPS traffic between our client and the server.

![Proxy host](https://imgur.com/hseHHG0.png)

Now we run the simulator along side Charles and see that whenever we refresh
the simulator we get new requests. Charles is now
intercepting the traffic.

![charles gif](http://i.giphy.com/3oEjHVw1hHOB0TNeeY.gif)

___
## Back to `curl`

So back to the beginning of this post, I said that we need the `Cache-Control`
header in the response from the server so that our app will cache responses. 

![Imgur](http://i.imgur.com/XK6JgdC.png)

We can't change the NASA server to add that header, but we can add it on the fly
right before the response gets to the simulator. Again we can use Charles to do
this. 

First turn on Rewrite Rules

![Rewrite Rules](https://imgur.com/i6SeeMp.png)

And then add a rewrite tool that automatically adds the `Cache-Control` header
with a `max-age=10000`.

![Add header](http://i.imgur.com/dP6eZQf.png)

The idea is that we'll add that header field to the server responses before
they get to our simulator, and then the simulator will see the `Cache-Control`
and actually cache the response.

We can give it a quick try in `curl` first to see if Charles is doing what we
want.

{% highlight sh %}
curl --proxy localhost:1234 -I https://api.nasa.gov/planetary/apodg?api_key=ZBrv2wKXCEGK34TQx21taIwI8nfxAQrdLWLpJ8to&date=2015-05-18
{% endhighlight %}

{% highlight sh %}
HTTP/1.0 200 Connection established

HTTP/1.1 200 OK
Age: 0
Content-Length: 1017
Content-Type: application/json
Date: Sun, 12 Jun 2016 01:15:20 GMT
Server: openresty
Vary: Accept-Encoding
Vary: Accept-Encoding
Via: 1.1 vegur, http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])
X-Cache: MISS
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 926
Cache-Control: max-age=10000
Connection: Keep-alive
{% endhighlight sh %}

We can confirm that Charles is indeed intercepting the request and adding the
`Cache-Control` header, so now let's see if iOS uses the cache.

Again, we keep Charles running and directed to intercept and alter all responses
before being passed to iOS. Now our counter `X-RateLimit-Remaining` is not
decreasing because we're getting the response for a request from
the cache, meaning we're saving API calls.

![with header](http://i.giphy.com/xT0GqhYPcEzyfEMLO8.gif)

Astute readers will notice the `X-RateLimit-Remaining` value for `05-19` is
decreasing while the others are staying the same. What gives?

Back to our good friend `curl`.

{% highlight sh %}
curl --proxy localhost:1234 -I https://api.nasa.gov/planetary/apod?api_key=ZBrv2wKXCEGK34TQx21taIwI8nfxAQrdLWLpJ8to\&date\=2015-05-19
{% endhighlight %}

{% highlight sh %}
HTTP/1.0 200 Connection established

HTTP/1.1 200 OK
Age: 0
Content-Length: 1192
Content-Type: application/json
Date: Sun, 12 Jun 2016 01:18:10 GMT
Server: openresty
Vary: Accept-Encoding
Vary: Accept-Encoding
Via: 1.1 vegur, http/1.1 api-umbrella (ApacheTrafficServer [cMsSf ])
X-Cache: MISS
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 924
Cache-Control: max-age=10000
Expires: 0
Cache-Control: no-cache
Connection: Keep-alive
{% endhighlight sh %}

Note that there are two `Cache-Control` fields here - one from the server and
one we've added through Charles. For some reason, the server is explicitly
telling us not to cache this response with the `no-cache` directive. So we've
got two conflicting values there for `Cache-Control`, and iOS is choosing not
to cache it. All of the other responses are silent about `Cache-Control`, so
that leads me to conclude that we should cache all the other responses. 

Obviously we can't always intercept the responses and add the header field.
What we need to do is subclass `NSURLCache` and implement our own caching
logic. That's for [Part 2]({% post_url 2016-06-12-Dive-Into-iOS-URL-Caching-Part-2 %}).

The test app used in this is available on [GitHub](https://github.com/idrisr/caching). Do a `git checkout part1` after cloning for the app as it was for this post.

For more information on caching with iOS, check out this
[NSHipster](http://nshipster.com/nsurlcache/) post.
