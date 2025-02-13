# SideKit

_SideKit allows apps to communicate with [SideServer mobile](https://github.com/SideStore/em_proxy) on **any** WiFi network and enable various features such as JIT compilation._

[![Unit Test](https://github.com/SideStore/SideKit/actions/workflows/test.yml/badge.svg)](https://github.com/SideStore/SideKit/actions/workflows/test.yml)

![Alt](https://repobeats.axiom.co/api/embed/c3dd1299b57265454681dab327b40e2dd52322e1.svg "Repobeats analytics image")

## Installation

To use AltKit in your app, add the following to your `Package.swift` file's dependencies:

```swift
.package(url: "https://github.com/SideStore/SideKit.git", .upToNextMajor(from: "0.0.1")),
```

Next, add the SideKit package as a dependency for your target:

```swift
.product(name: "SideKit", package: "SideKit),
```

Finally, right-click on your app's `Info.plist`, select "Open As > Source Code", then add the following entries:

```xml
<key>ALTDeviceID</key>
<string></string>
```

⚠️ The `ALTDeviceID` key must be present in your app's `Info.plist` to let AltStore know it should replace that entry with the user's device's UDID when sideloading your app, which is required for AltKit to work. For local development with AltKit, we recommend setting `ALTDeviceID` to your development device's UDID to ensure everything works as expected. Otherwise, the exact value doesn't matter as long as the entry exists, since it will be replaced by AltStore during installation.

### CMake Integration

Note: CMake 3.15 is required for the integration. The integration only works with the Xcode generator.

Steps:
- Add the AltKit CMake project to your CMake project using `add_subdirectory`.
- Add Swift to your project's supported languages. (ex.: `project(projName LANGUAGES C Swift)`)

If you're using `add_compile_options` or `target_compile_options` and the Swift compiler complains about the option not being supported, it's possible to use CMake's generator expressions to limit the options to non-Swift source files.

Example:

```cmake
add_compile_options($<$<NOT:$<COMPILE_LANGUAGE:Swift>>:-fPIC>)
```

## Usage

### Swift

```swift
import SideKit

ServerManager.shared.startDiscovering()

ServerManager.shared.autoconnect { result in
    switch result
    {
    case .failure(let error): print("Could not auto-connect to server.", error)
    case .success(let connection):
        connection.enableUnsignedCodeExecution { result in
            switch result
            {
            case .failure(let error): print("Could not enable JIT compilation.", error)
            case .success: 
                print("Successfully enabled JIT compilation!")
                ServerManager.shared.stopDiscovering()
            }
            
            connection.disconnect()
        }
    }
}
```

### Objective-C

```objc
@import SideKit;

[[ALTServerManager sharedManager] startDiscovering];

[[ALTServerManager sharedManager] autoconnectWithCompletionHandler:^(ALTServerConnection *connection, NSError *error) {
    if (error)
    {
        return NSLog(@"Could not auto-connect to server. %@", error);
    }
    
    [connection enableUnsignedCodeExecutionWithCompletionHandler:^(BOOL success, NSError *error) {
        if (success)
        {
            NSLog(@"Successfully enabled JIT compilation!");
            [[ALTServerManager sharedManager] stopDiscovering];
        }
        else
        {
            NSLog(@"Could not enable JIT compilation. %@", error);
        }
        
        [connection disconnect];
    }];
}];
```
