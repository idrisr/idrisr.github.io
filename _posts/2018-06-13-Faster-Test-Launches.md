---
layout: post
title:  "Faster iOS Test Launches"
date:   2018-06-13 21:37:12
published: true
---

I detest waiting for the simulator to launch to run tests, especially when the
app does anything time-consuming at launch like network calls or configuring a
persistence layer.

There is a trick to get around this.

```swift
public protocol UIApplicationDelegate : NSObjectProtocol {
  optional public var window: UIWindow? { get set }
  ...
}
```

```swift
open class UIWindow : UIView {
  open var rootViewController: UIViewController? // default is nil
  ...
```

The `UIApplicationDelegate` has a `UIWindow?` property, which has a `UIViewController?` which is the app's `rootViewController`.

These are all optional properties, so we can give those properties a `nil` value. With no `rootViewController`, the app won't create any `UIViewController`s, and it won't kick off any of the work they do in the app.

One way to achieve this is as follows:

1. create another object to be your `AppDelegate`, we'll call this the `TestingAppDelegate`
1. include `TestingAppDelegate` in your test target only
1. remove the `@UIApplicationMain` line from the existing `AppDelegate`
1. create a `Main.swift` file
1. within `Main.swift`, we'll set the `delegateClassName` in our invocation of `UIApplicationMain` to the empty `TestingAppDelegate` if we're in the test target, and if we're in the main target we'll use the usual `AppDelegate`

It looks like this:

``` swift
// file: TestingAppDelegate.swift

import UIKit

class TestingAppDelegate: NSObject {
    @objc var window: UIWindow?
}
```

```swift
// file: Main.swift

import UIKit

let test_target = "MyTestTarget"

// if Test Delegate is found, use it otherwise use the default App Delegate
// the Test Delegate is not included as a compile source for the App target
let appDelegateClass: AnyClass? = NSClassFromString("\(test_target).TestingAppDelegate") ?? AppDelegate.self
let args = UnsafeMutableRawPointer(CommandLine.unsafeArgv) .bindMemory(to: UnsafeMutablePointer<Int8>.self, capacity: Int(CommandLine.argc))
UIApplicationMain(CommandLine.argc, args, nil, NSStringFromClass(appDelegateClass!))
```

```swift
// file: AppDelegate.swift

// @UIApplicationMain -- delete or comment this line
class AppDelegate: UIResponder, UIApplicationDelegate
```

And now when the simulator is launched for your test target, `UIWindow?` will be nil and the simulator won't do anything so you can get to the testing right away.
