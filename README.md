# SMG App SDK — iOS

Native in-app survey SDK (digital intercept) for iOS. Surveys render natively (no
webview), fire on in-app events / screen loads / manual calls, and responses are
submitted to SMG's collection API.

This repository is the **distribution channel**: it contains the compiled
XCFramework and the Swift Package manifest that points at it. The SDK source is
maintained privately by SMG.

## Requirements

- iOS 15+
- Xcode 15+

## Install (Swift Package Manager)

In Xcode: **File → Add Package Dependencies…** and enter

```
https://github.com/ServiceManagementGroup/smg-survey-sdk-ios
```

Choose the version you want (semantic versioning; each tag is immutable).

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ServiceManagementGroup/smg-survey-sdk-ios", from: "0.3.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "SMGSurveyKit", package: "smg-survey-sdk-ios")
    ])
]
```

## Usage

The module is `SMGSurveyKit`; the entry point is the `SMGSurveySDK` facade.

```swift
import SMGSurveyKit

// At app launch — non-blocking.
SMGSurveySDK.configure(
    apiKey: "<your key>",
    projectId: "<your project>",
    environment: .production
)

// Instrument your screens and events; SMG owns when a survey fires.
SMGSurveySDK.trackScreenView(name: "cart")
SMGSurveySDK.trackEvent(
    name: "order_completed",
    properties: ["payment_method": "apple_pay", "order_id": "A1234"]
)

// Optional: brand override, consent gate, GDPR deletion.
SMGSurveySDK.setTheme(SMGTheme(primary: brandColor))
SMGSurveySDK.setConsent(granted: true)
SMGSurveySDK.deleteAllLocalData()
```

Surveys, trigger rules, theming and suppression are configured **server-side by
SMG** — your app only supplies credentials and instrumentation. The SDK never
throws into your app: any internal failure is logged and swallowed.

Without a valid, entitled API key the SDK is inert (no surveys, no submissions).

## Objective-C

The SDK ships an Objective-C bridge; see the `SMGSurveySDKBridge` class.

## Support

Contact your SMG implementation engineer.
