---
title:  "Part 2. Network Caching and iOS"
date:   2016-06-12 21:35:12
published: true
toc: true
---

When we last left off from [Part 1]({% post_url 2016-06-11-Dive-Into-iOS-URL-Caching %}) , we saw that the server was
telling our app not to cache responses. Normally one should respect the wishes
of the server, but in this case I'm going to disobey. We're only given 1000
requests per hour, and it's unlikely the Photo of the Day is going to change.

In [Part 1]({% post_url 2016-06-11-Dive-Into-iOS-URL-Caching %}) we used
Charles to intercept the server responses to add the `Cache-Control` header,
and now we are going to do the same thing inside the app. 


___
### Set up the shared cache in `AppDelegate`

{% highlight sh %}
//  AppDelegate.swift
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // 1
        let cache = NasaURLCache(memoryCapacity: 1024 * 1024 * 30, diskCapacity: 1024 * 1024 * 100, diskPath: nil)
        NSURLCache.setSharedURLCache(cache)
        return true
    }
}
{% endhighlight %}

First we set up the shared cache to be our subclass of `NSURLCache` with a
memory size of 30 MB and a disk size of 100 MB.

___
### Subclass `NSURLCache`

{% highlight sh %}
//  NasaURLCache.swift

import UIKit

class NasaURLCache: NSURLCache {
    override func storeCachedResponse(cachedResponse: NSCachedURLResponse, forRequest request: NSURLRequest) {

        // 1
        guard let response = cachedResponse.response as? NSHTTPURLResponse else {
            NSLog("couldn't convert to http response")
            return
        }

        // 2
        guard response.statusCode == 200 else {
            if response.statusCode == 429 {
                NSLog("Over API Hourly Limit")
            } else {
                NSLog("\(response.statusCode)")
            };
            return
        }

        // 3
        var headers = response.allHeaderFields
        headers.removeValueForKey("Cache-Control")
        headers["Cache-Control"] = "max-age=\(7 * 24 * 60 * 60)"

        // 4
        if let
            headers = headers as? [String: String],
            newHTTPURLResponse = NSHTTPURLResponse(URL: response.URL!, statusCode: response.statusCode, HTTPVersion: "HTTP/1.1", headerFields: headers) {
                let newCachedResponse = NSCachedURLResponse(response: newHTTPURLResponse, data: cachedResponse.data)
                super.storeCachedResponse(newCachedResponse, forRequest: request)
        }
    }
}
{% endhighlight %}

Every time one of our `NSURLSessionDataTask`'s from the singleton
`NetworkClient` successfully finishes, `storeCachedResponse(_:forRequest:)` is
called. Here we subclass `NSURLCache` and override that method to inject the
`Cache-Control` header to the response header before calling the `super`'s
method `storeCachedResponse(_:forRequest:)`.

___
#### Step 1:

We check to see if we can convert the `NSURLResponse` to a `NSHTTPURLResponse`,
and if not, we exit before caching.

___
#### Step 2:

We check to see if we got a success status code, and if not exit before
caching.

___
#### Step 3:

Here we grab the old headers, remove `Cache-Control` if it exists, and then add
it back with a `max-age` of one week.

___
#### Step 4:
We try to cast `headers` to a `Dictionary` of type `[String: String]` and to
create a new `NSHTTPURLResponse`. If both succeed, we
instruct the `super` to store the response.

This is all pretty straightforward, and the same thing we did in 
[Part 1]({% post_url 2016-06-11-Dive-Into-iOS-URL-Caching %}) 
with Charles.

Now when we run the app without intercepting responses with Charles, we see
that refreshes do not cause our hourly API limit to decrease. If we clear the
cache and then do a refresh, we do hit the server and our quota decreases.

![custom cache](http://i.giphy.com/l41Ya2daJKHMH2yFG.gif)
