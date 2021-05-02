---
layout: post
title:  "Universal Links & Associated Domains"
date:   2018-06-29 21:37:12
published: true
---

You have an app, you also have a website. You have links which typically open
your website. But if the link is on a device with your app, you'd rather open
your app instead.

Universal links are the iOS technology that allow you to do just that.

To have your app open the link, you first must prove that you control the domain
which the link would go to otherwise absent your app - the "Associated Domain."

This requires an intricate yet simple dance between your app, Apple, and
the associated domain. There are plenty of tutorials on what you need to do as
far as entitlements, json files, file formats, provisioning profiles,
certificates, and so on, but none that I found that explain the why.


![Universal Links](https://s3.amazonaws.com/octoporess_blog/universal-links/UniversalLinks.jpg)


To do this, we start at the top of the diagram. You must tell Apple via your
developer's account which associated domain(s) go with your app. This
information will then get bundled into your Provisioning Profile and will find
itself onto any device that installs your app.

At some point, probably right when the app is installed, the system will reach
across the web to any associated domains in the provisioning profile, and check
for the file  `apple-app-site-association`. The system will check the app-id in that file to see whether it matches an app on the device.

If that succeeds, then when the user opens a link on the device, it'll go to
your app instead of the browser.

If it fails, or if your app is not on the device, then the link will open the browser.

That's it, simple yet not obvious.
