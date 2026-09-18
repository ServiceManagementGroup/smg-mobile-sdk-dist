# SMG App SDK

Native in-app survey SDK for **iOS and Android**. Your app supplies credentials,
consent and screen/event instrumentation; SMG configuration controls surveys and
placements. Surveys render natively and responses go to the collection API.

This repository distributes the compiled SDK. The source is maintained privately
by SMG.

| | iOS | Android |
|---|---|---|
| Artifact | `SMGSurveyKit.xcframework` | `smg-surveysdk-<version>.aar` |
| Channel | GitHub Releases through Swift Package Manager | Maven repository on GitHub Pages through Gradle |
| Download credentials | None | None |
| Minimum OS | iOS 15 | Android API 26 |

Documented release: **[0.5.4](https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/tag/0.5.4)**,
verified September 18, 2026.

**[Integration guide](INTEGRATION.md)** — requirements, installation, configuration,
instrumentation, themes, consent, diagnostics, full facade reference and
troubleshooting, with Swift, Objective-C, Kotlin and Java examples.

## iOS

In Xcode, choose **File → Add Package Dependencies…** and enter:

```text
https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist
```

Select version **0.5.4** and add the **SMGSurveyKit** product to your app target.
Use an Xcode version compatible with the framework's Swift module interface. The
manifest uses Swift tools 5.9; that alone does not establish binary compatibility
with every older Xcode.

At app launch, using credentials provisioned for Stage:

```swift
import SMGSurveyKit

// hasSurveyConsent comes from your app's consent state.
SMGSurveySDK.setConsent(granted: hasSurveyConsent)
SMGSurveySDK.configure(
    apiKey: "<staging-api-key>",
    projectId: "<staging-project-id>",
    environment: .staging
)
```

As screens appear and actions complete, emit the names agreed with SMG:

```swift
SMGSurveySDK.trackScreenView(name: "cart")
SMGSurveySDK.trackEvent(
    name: "order_completed",
    properties: ["payment_method": "apple_pay"]
)
```

Objective-C hosts use the shipped `SMGSurveySDKBridge` and `SMGThemeBridge`,
without a host Swift shim. See the [Objective-C examples](INTEGRATION.md#objective-c).

## Android

Use minSdk 26+, compileSdk 36+, JDK 17+ and compatible AGP/AndroidX versions. The
SDK is built with AGP 8.13.2 and Kotlin 2.2.21; Kotlin callers need Kotlin 2.1+.
Java hosts are supported. AndroidX, Compose and Material 3 dependencies are
resolved transitively by Gradle.

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://servicemanagementgroup.github.io/smg-mobile-sdk-dist/maven")
        }
    }
}

// app/build.gradle.kts
dependencies {
    implementation("com.smg:smg-surveysdk:0.5.4")
}
```

Configure in `Application.onCreate()` so the SDK observes the first Activity:

```kotlin
import com.smg.surveysdk.Env
import com.smg.surveysdk.SMGSurveySDK

// hasSurveyConsent comes from your app's consent state.
SMGSurveySDK.setConsent(granted = hasSurveyConsent)
SMGSurveySDK.configure(
    context = this,
    apiKey = "<staging-api-key>",
    projectId = "<staging-project-id>",
    env = Env.STAGING,
)
```

Instrument screen appearances and completed actions:

```kotlin
SMGSurveySDK.trackScreenView("cart")
SMGSurveySDK.trackEvent("order_completed", mapOf("payment_method" to "google_pay"))
```

Presentation requires a resumed AndroidX `ComponentActivity`;
`AppCompatActivity` and `FragmentActivity` qualify. The host can use Views or
Compose. The AAR contributes `android.permission.INTERNET` to the merged manifest.
Java hosts use static facade methods and `SMGTheme.Builder`; see the
[Java examples](INTEGRATION.md#java).

## Endpoint and configuration

Stage automatically uses `https://mobile-sdk-stage.smg.com/api/sdk/v1`.
**Production requires an explicit HTTPS base URL supplied by SMG:** call
`setCollectionBaseURL` (iOS) or `setCollectionBaseUrl` (Android) before configuring
with production credentials and `.production` / `Env.PRODUCTION`.

The SDK has no bundled mock transport or survey catalog. Clearing the URL disables
networking; it does not erase cached config. See
[Configure](INTEGRATION.md#4-configure) for initialization order and endpoint behavior.

Config fetches are asynchronous. A trigger emitted before the first config arrives
is not replayed automatically. In 0.5.4, `configuredSurveys()` lets Swift, Kotlin
and Java hosts inspect the available config; it does not trigger a fetch or
guarantee that a listed survey is eligible.

## Integration checks

- Use `previewSurvey` to inspect a configured survey without submitting its response
  or recording suppression. Consent and a usable presenter are still required.
- Use normal screen/event/manual triggers to check the actual placement rules.
- `setDryRun(true)` keeps presentation enabled and skips enqueueing new survey
  responses. Config/tracking requests and existing queued delivery can continue.
- Themes support light/dark host overrides on both platforms. Contrast is checked
  when publishing server themes; the SDK does not reject host colors for contrast.

See [Integration tools](INTEGRATION.md#9-integration-tools) and
[Troubleshooting](INTEGRATION.md#12-troubleshooting) for details.

## Versioning and support

Release tags are immutable. Fixes ship under a new version; published binaries and
SwiftPM checksums are not replaced under an existing tag.

For support, provide your project ID, platform, SDK version and relevant SDK logs
to your SMG implementation contact. Exclude credentials and personal/answer data.
