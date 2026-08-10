# SMG App SDK

Native in-app survey SDK (digital intercept) for **iOS and Android**. Surveys
render natively (no webview), fire on in-app events / screen loads / manual
calls, and responses are submitted to SMG's collection API.

This repository is the **distribution channel** for both platforms: it holds the
compiled artifacts and the metadata clients resolve them through. The SDK source
is maintained privately by SMG.

| | iOS | Android |
|---|---|---|
| Artifact | `SMGSurveyKit.xcframework` | `smg-surveysdk-<version>.aar` |
| Served from | GitHub Releases on this repo | static Maven repo on this repo's GitHub Pages |
| Resolved with | Swift Package Manager | Gradle |
| Credentials needed | none | none |

Latest version: **0.4.0**.

📖 **[Integration guide](INTEGRATION.md)** — install, instrumentation, theming,
consent, bring-up tooling, full API reference and troubleshooting. Start there for
anything beyond the snippets below.

---

## iOS

**Requirements:** iOS 15+, Xcode 15+.

In Xcode: **File → Add Package Dependencies…** and enter

```
https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist
```

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist", from: "0.4.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "SMGSurveyKit", package: "smg-mobile-sdk-dist")
    ])
]
```

The module is `SMGSurveyKit`; the entry point is the `SMGSurveySDK` facade. The
two names differ on purpose — a top-level type named like its module breaks the
library-evolution interface in client builds.

> **New integration?** By default the SDK serves surveys from a mock bundled
> inside it. Point it at a real endpoint with `setCollectionBaseURL` — see
> [Integration guide §4](INTEGRATION.md#4-configure).

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

### Objective-C

The SDK ships an Objective-C bridge covering the same surface — Swift structs
and enums are invisible to Objective-C, so the bridge takes plain `NSString` and
`UIColor`.

```objc
@import SMGSurveyKit;

[SMGSurveySDKBridge configureWithApiKey:@"<your key>"
                              projectId:@"<your project>"
                            environment:@"production"];

[SMGSurveySDKBridge trackScreenViewWithName:@"cart"];
[SMGSurveySDKBridge trackEventWithName:@"order_completed"
                            properties:@{@"payment_method": @"apple_pay"}];

SMGThemeBridge *theme = [SMGThemeBridge new];
theme.primary = brandColor;
[SMGSurveySDKBridge setTheme:theme];
```

---

## Android

**Requirements:** minSdk 26.

Add the repository and the coordinate. The Maven layout is plain files over
HTTPS — no credentials, and no `read:packages` token.

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://servicemanagementgroup.github.io/smg-mobile-sdk-dist/maven") }
    }
}

// app/build.gradle.kts
dependencies {
    implementation("com.smg:smg-surveysdk:0.4.0")
}
```

```kotlin
import com.smg.surveysdk.Env
import com.smg.surveysdk.SMGSurveySDK
import com.smg.surveysdk.SMGTheme

// At app launch — non-blocking.
SMGSurveySDK.configure(
    context = this,
    apiKey = "<your key>",
    projectId = "<your project>",
    env = Env.PRODUCTION,
)

SMGSurveySDK.trackScreenView("cart")
SMGSurveySDK.trackEvent(
    "order_completed",
    mapOf("payment_method" to "google_pay", "order_id" to "A1234"),
)

SMGSurveySDK.setTheme(SMGTheme(primary = brandColor))
SMGSurveySDK.setConsent(granted = true)
SMGSurveySDK.deleteAllLocalData()
```

### Java

Every entry point is `@JvmStatic`, so Java calls it the same way. Themes are the
one exception: build them rather than using the positional constructor, which
would force you to spell out every preceding token.

```java
SMGSurveySDK.configure(this, "<your key>", "<your project>", Env.PRODUCTION);
SMGSurveySDK.trackScreenView("cart");

SMGSurveySDK.setTheme(new SMGTheme.Builder()
    .primary(0xFF003366)
    .textOnAccent(0xFFFFFFFF)
    .build());
```

Colors are packed ARGB ints, the same as `android.graphics.Color`.

---

## How it behaves

Surveys, trigger rules, theming and suppression are configured **server-side by
SMG** — your app only supplies credentials and instrumentation.

- **The SDK never throws into your app.** Every public entry point catches
  internally; a failure is logged and swallowed. A survey that does not show is
  acceptable, a host-app crash is not.
- **No third-party dependencies** on either platform.
- **Inert without entitlement.** Without a valid, entitled API key there are no
  surveys and no submissions — which is why these artifacts are safe to serve
  publicly.

## Versioning

Semantic versioning; each tag is immutable. A published SwiftPM checksum is
pinned by every client that already resolved it, so an artifact is never
replaced under an existing tag — fixes ship as a new patch version.

## Support

Start with the [integration guide](INTEGRATION.md) — its troubleshooting section
covers the failure modes integrators actually hit. Beyond that, contact your SMG
implementation engineer with your project ID, the SDK version (`sdkVersion`) and a
dry-run log.
