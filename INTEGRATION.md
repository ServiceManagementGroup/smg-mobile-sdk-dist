# Integration guide

How to add the SMG App SDK to an iOS or Android app, from installation to a survey
on screen. For shorter examples, see the [README](README.md).

Applies to **[0.5.4](https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/tag/0.5.4)**,
reviewed September 18, 2026 against that release's SDK source and public artifacts.
The examples use APIs available in this version. `configuredSurveys()` was added
in 0.5.4; upgrade before using the catalog examples with an older integration.

## Contents

1. [How it works](#1-how-it-works)
2. [Requirements](#2-requirements)
3. [Install](#3-install)
4. [Configure](#4-configure)
5. [Instrument your app](#5-instrument-your-app)
6. [When a survey appears](#6-when-a-survey-appears)
7. [Theming](#7-theming)
8. [Consent and privacy](#8-consent-and-privacy)
9. [Integration tools](#9-integration-tools)
10. [Offline and reliability](#10-offline-and-reliability)
11. [API reference](#11-api-reference)
12. [Troubleshooting](#12-troubleshooting)

## 1. How it works

Your app supplies credentials, consent and instrumentation. SMG configuration
supplies the surveys, placement rules, appearance and suppression settings. The
SDK fetches that configuration over HTTP, caches it, renders surveys natively and
submits responses to the collection API.

Your app calls `configure` once at launch, `trackScreenView` when a screen appears,
and `trackEvent` when a relevant action happens. A feedback button can call
`presentSurvey` for a survey with a manual placement. Agree screen names, event
names, property values and manual survey IDs with your SMG implementation contact.

The SDK ships **no mock transport or bundled survey catalog**. Installing the
artifact does not provision an API key, project, endpoint or survey configuration.

The public methods do not expose throwing APIs; SDK failures are logged and handled
internally. This is not a guarantee against every process crash: for example,
Swift error handling does not catch Swift traps or Objective-C exceptions.

There are no public survey lifecycle callbacks or answer getters in 0.5.4. The
catalog API returns survey metadata, not responses or presentation notifications.

## 2. Requirements

| | iOS | Android |
|---|---|---|
| OS | iOS 15+ | minSdk 26+ |
| Build tooling | Xcode with SwiftPM; package manifest uses Swift tools 5.9 | compileSdk 36+; JDK 17+; SDK built with AGP 8.13.2 |
| Host language | Swift or Objective-C through the shipped bridge | Kotlin 2.1+ for Kotlin callers, or Java |
| Runtime dependencies | Apple frameworks | Kotlin, AndroidX, Jetpack Compose and Material 3, resolved by Gradle |
| SDK manifest permissions | No additional app permission | `android.permission.INTERNET` is contributed by the AAR |

Use an Xcode version compatible with the published framework's Swift module
interface. The package manifest's tools version is not a guarantee that every
older Xcode can import a binary built with a newer Swift compiler.

The AAR is built with Kotlin 2.2 and targets Java 8 bytecode. Kotlin callers need
Kotlin 2.1+ to read its metadata; Java 8 bytecode compatibility does not mean Gradle
can run on JDK 8. Use an AGP version compatible with your compile SDK and the
resolved AndroidX dependencies; the SDK build uses AGP 8.13.2 and Kotlin 2.2.21.

Android presentation requires a resumed AndroidX `ComponentActivity`.
`FragmentActivity` and `AppCompatActivity` qualify; a plain `android.app.Activity`
does not. Your host UI can use Views or Compose. Configure the SDK in
`Application.onCreate()` so it can observe the first Activity's lifecycle.

## 3. Install

Artifact downloads are public and require no GitHub token or package credentials.
The collection API separately requires the credentials supplied by SMG.

### iOS — Swift Package Manager

In Xcode, choose **File → Add Package Dependencies…**, enter the URL below, select
version **0.5.4**, and add the **SMGSurveyKit** product to your app target:

```text
https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist
```

For a package-based host:

```swift
dependencies: [
    .package(
        url: "https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist",
        exact: "0.5.4"
    )
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "SMGSurveyKit", package: "smg-mobile-sdk-dist")
    ])
]
```

This resolves the compiled XCFramework for device and simulator. Import
`SMGSurveyKit`; call the `SMGSurveySDK` facade. Pinning the release keeps your
integration aligned with this guide; choose a version range if your update policy
allows later releases. Do not use the distribution repository's branch as a
version pin.

### Android — Gradle

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
android {
    compileSdk = 36
    defaultConfig {
        minSdk = 26
    }
}

dependencies {
    implementation("com.smg:smg-surveysdk:0.5.4")
}
```

Gradle resolves the AAR and its transitive dependencies from the published Maven
metadata. Prefer the Maven dependency to copying the AAR alone, which would leave
you responsible for those dependencies. The SDK requires no extra ProGuard/R8
keep rules; its consumer rules file is empty.

## 4. Configure

Obtain an API key and project ID for the intended environment. For production,
also obtain the approved HTTPS collection base URL, including its API path.

| Environment | Endpoint behavior |
|---|---|
| `.staging` / `Env.STAGING` | Defaults to `https://mobile-sdk-stage.smg.com/api/sdk/v1` |
| `.production` / `Env.PRODUCTION` | No built-in endpoint; set the supplied URL before `configure` |
| Explicit URL override | Takes precedence over the environment default |

Set any required consent and locale overrides before configuring. Configuration
fetches run asynchronously; returning from `configure` does not mean a survey is
ready. Credentials and project/environment are initialized once per process;
later calls do not switch them, including after `deleteAllLocalData()`.

**Swift — Stage setup at app launch**

```swift
import SMGSurveyKit

// Read this from your app's consent state.
SMGSurveySDK.setConsent(granted: hasSurveyConsent)
SMGSurveySDK.configure(
    apiKey: "<staging-api-key>",
    projectId: "<staging-project-id>",
    environment: .staging
)
```

**Kotlin — Stage setup in `Application.onCreate()`**

```kotlin
import com.smg.surveysdk.Env
import com.smg.surveysdk.SMGSurveySDK

// Read this from your app's consent state.
SMGSurveySDK.setConsent(granted = hasSurveyConsent)
SMGSurveySDK.configure(
    context = this,
    apiKey = "<staging-api-key>",
    projectId = "<staging-project-id>",
    env = Env.STAGING,
)
```

For **production**, use production credentials and select `.production` /
`Env.PRODUCTION`. Before `configure`, supply your provisioned endpoint:

```swift
// collectionBaseURL is the URL supplied by SMG for your production environment.
SMGSurveySDK.setCollectionBaseURL(collectionBaseURL)
```

```kotlin
// collectionBaseUrl is the full HTTPS base URL supplied by SMG.
SMGSurveySDK.setCollectionBaseUrl(collectionBaseUrl)
```

Keep endpoint selection in app initialization. Changing it also redirects later
delivery of responses already queued. If you correct the endpoint after
configuration, call `refreshConfiguration()` to request a new config.

Passing `nil` / `null` clears the active endpoint; network operations then fail
internally with `notConfigured`. It does not erase a usable configuration cache
or switch to demo data. To restore networking, explicitly set the intended URL.
Use `setConsent(false)` to gate SDK activity rather than using an unset endpoint.
Production integrations should use HTTPS; local development exceptions are not a
production transport option.

## 5. Instrument your app

Replace the sample names and IDs below with the ones configured for your project.

### Screen views

Call when the screen becomes visible, such as `viewDidAppear` on iOS or the
appropriate navigation/lifecycle hook on Android. Avoid emitting a new screen
view on every SwiftUI body evaluation or Compose recomposition.

```swift
SMGSurveySDK.trackScreenView(name: "cart", properties: ["tier": "gold"])
```

```kotlin
SMGSurveySDK.trackScreenView("cart", mapOf("tier" to "gold"))
```

Use stable names matching the server's placement rules. A tracked screen does
not necessarily trigger a survey. Screen views are also sent to the collection API.

### Events

```swift
SMGSurveySDK.trackEvent(
    name: "order_completed",
    properties: ["payment_method": "apple_pay"]
)
```

```kotlin
SMGSurveySDK.trackEvent(
    "order_completed",
    mapOf("payment_method" to "google_pay"),
)
```

Properties participate in placement matching. Agree their names and allowed
values with SMG; unexpected values may not match any rule. Use non-PII metadata,
not email addresses, phone numbers, payment details or user-entered free text.

The SDK accepts at most **20 properties**, with keys up to **64 characters** and
values up to **256 characters**. Invalid entries are dropped and logged rather
than truncated; excess keys are selected in lexicographic order.

### Manual presentation

For a feedback button:

```swift
SMGSurveySDK.presentSurvey(surveyId: "<your-survey-id>", from: viewController)
```

```kotlin
SMGSurveySDK.presentSurvey("<your-survey-id>")
```

The survey needs a `manual` placement. Manual presentation bypasses the session
throttle but still checks consent, configuration, entitlement, cooldown and
whether another survey is active. The catalog's `hasManualPlacement` field helps
populate a picker; it does not certify that a survey is currently eligible.

Both platforms accept an optional `style` for that call: modal, bottom sheet or
bottom-docked banner. On iOS, omit `from` to let the SDK find a presentation
controller. On Android, the SDK uses the resumed Activity.

### Locale

The app/device locale is used by default. Set a BCP-47 override if your app manages
its own language preference:

```swift
SMGSurveySDK.setLocaleOverride("es-UY")
```

```kotlin
SMGSurveySDK.setLocaleOverride("es-UY")
```

Pass `nil` / `null` to restore the default. The override is not persisted; reapply
your app's choice at launch, preferably before configuring. Changes request
configuration for the selected locale and affect later presentations. Translations
must be authored server-side; an override does not translate missing content.
Config caches are scoped by project, environment and locale.

## 6. When a survey appears

Normal presentation checks the following conditions:

| Check | Behavior |
|---|---|
| Initialization, consent and configuration | SDK must be configured, consent granted and a usable config available |
| One active survey | A second survey is skipped while one is active |
| Entitlement | Config must permit survey presentation |
| Session throttle | Automatic triggers respect the configured session limit; manual calls bypass it |
| Cooldown | The survey's configured cooldown is checked, including for manual calls |
| Placement | Trigger type, screen/event name and applicable properties must match |
| Presenter and questionnaire | Host must be ready to present and the questionnaire must be renderable |

Automatic screen/event triggers also skip presentation while the host is accepting
text input or the keyboard is visible. Manual calls and previews can proceed.
Suppression is recorded only after successful presentation readiness; preview
never records it.

On a first launch without a cache, a screen/event can arrive before config fetch
completes. Such a trigger is **not replayed automatically**. A later visit can
trigger the survey. A usable cache reduces that dependency on later launches,
but there is no fixed 200 ms readiness guarantee.

For integration checks, use the catalog and preview tools below, then verify the
real screen/event/manual path with your project's placement rules.

## 7. Theming

Server configuration supplies 35 appearance fields, including dark variants,
fonts, radii and opacities. Host overrides take precedence, then server values,
then SDK defaults.

The host's `SMGTheme` exposes **11 color overrides and a font**: `primary`,
`background`, `surface`, `text`, `accent`, `textOnAccent`, `textSecondary`,
`textPlaceholder`, `border`, `borderControl`, `error`, and `font`. Set only what
you want to override. Pass an empty theme to restore server/default values.

**Swift**

```swift
SMGSurveySDK.setTheme(SMGTheme(
    primary: brandColor,
    textOnAccent: .white
))
```

**Kotlin**

```kotlin
import com.smg.surveysdk.SMGColor
import com.smg.surveysdk.SMGTheme

SMGSurveySDK.setTheme(SMGTheme(
    primary = SMGColor(0xFF003366.toInt(), 0xFF88AACC.toInt()),
    textOnAccent = SMGColor(0xFFFFFFFF.toInt()),
))
```

Java hosts can use `SMGTheme.Builder` (see §11). Its color setters accept a packed
ARGB integer, a light/dark pair, or an `SMGColor`. The Kotlin constructor accepts
`SMGColor`, not raw integers.

Spacing, type scale, component minimums, shadows and the disabled palette are
fixed by the SDK. There is no logo override.

### Validation

Contrast is validated when a theme is published in Forge. The SDK does not reject
host or server colors for contrast. It range-checks scalar values such as radii,
weights and opacities and exposes diagnostics from the server's
`theme.validation_issues` along with local validation results:

```swift
SMGSurveySDK.lastThemeValidationMessages()
```

```kotlin
SMGSurveySDK.lastThemeValidationMessages()
```

These describe the most recent theme resolution. An empty list is not an
accessibility certification of your host override. Check the resulting palette
in both appearances and at your supported text sizes.

### Dark mode

For server colors, the cascade in dark mode is the `*_dark` field, then the light
field, then the SDK default. Host overrides take precedence in both modes:

- **iOS:** use a dynamic `UIColor`, such as an asset-catalog color with Any/Dark
  variants. A static `UIColor` supplies the same color in both modes.
- **Android:** use `SMGColor(light, dark)`, or
  `SMGColor.fromResource(R.color.brand)` backed by `res/values` and
  `res/values-night`. `SMGColor(color)` uses one value in both modes.

## 8. Consent and privacy

### Consent and deletion

Consent defaults to granted until the host sets it. If your app requires prior
consent, set it to `false` **before `configure`** and grant it only when your app's
consent flow permits SDK activity:

```swift
SMGSurveySDK.setConsent(granted: false)
```

```kotlin
SMGSurveySDK.setConsent(granted = false)
```

The choice persists across launches. With consent withheld, new triggers,
tracking submissions, config refreshes and response delivery are gated. Previously
queued responses remain stored and can retry when consent is granted again.

In 0.5.4, **Android cancels an active survey on withdrawal; iOS leaves it visible
and gates its completion while consent is withheld**. Do not assume the consent
setter dismisses iOS UI or retracts a request already sent.

For local deletion, call `SMGSurveySDK.deleteAllLocalData()` on either platform.
It clears the config cache, queued responses and suppression state and cancels
active presentation. It does not reset credentials or the consent choice, and it
does not delete data already submitted to SMG. If the app also needs SDK activity
to remain disabled, withhold consent before deletion.

### Data and storage

The SDK sends survey answers and context such as screen/event names, supplied
metadata, project/survey/placement identifiers, app and OS versions, locale and
SDK version. Version 0.5.4 includes survey start and collection timestamps in UTC;
they retain their original instants across offline response retries and depend on
the device clock. Screen/event tracking also sends requests independently of
survey responses.

The SDK does not add advertising identifiers, cross-app tracking or device
fingerprinting. Keep host-supplied metadata consistent with your application's
data disclosures. Queued responses and configuration are stored in app-private
files; consent/cooldown use preferences. These are not SDK-encrypted secure stores.

### Platform manifests

The iOS framework bundles `PrivacyInfo.xcprivacy`, declaring:

- No tracking or tracking domains.
- Other User Content for App Functionality, not linked to identity or used for
  tracking.
- Required-reason API entries for `UserDefaults` (`CA92.1`) and file timestamps
  (`C617.1`).

Android's AAR declares `android.permission.INTERNET`, which merges into the host
manifest. Review the built app's privacy report, merged manifest and store
disclosures in the context of your complete app and actual data use.

## 9. Integration tools

Use Stage credentials and your own configured survey IDs when checking an
integration. The SDK does not bundle test surveys.

### Inspect the configured catalog — new in 0.5.4

```swift
let surveys = SMGSurveySDK.configuredSurveys()
let manualSurveys = surveys.filter { $0.hasManualPlacement }
```

```kotlin
val surveys = SMGSurveySDK.configuredSurveys()
val manualSurveys = surveys.filter { it.hasManualPlacement }
```

This returns a snapshot in server order, including usable cached configuration.
Each `SMGSurveyInfo` contains `surveyId`, `name`, `presentationStyle` and
`hasManualPlacement`. It makes no HTTP request and returns an empty list before
config is available or after cache deletion. Read it again after a refresh has
completed; there is no public refresh-completion callback. Metadata is not an
eligibility check. The catalog is available to Swift, Kotlin and Java; the
Objective-C bridge does not expose it in 0.5.4.

### Preview a survey

```swift
SMGSurveySDK.previewSurvey(surveyId: "<your-survey-id>", from: viewController)
```

```kotlin
SMGSurveySDK.previewSurvey("<your-survey-id>")
```

Preview bypasses placements, entitlement, cooldown and session throttle. It still
requires initialization, consent, a survey in config, no active survey, a usable
presenter and a renderable questionnaire. It records no suppression and does not
enqueue its response. Other SDK networking remains enabled.

Use preview for appearance and layout, then use normal triggers or `presentSurvey`
to verify the actual integration rules.

### Dry run

```swift
SMGSurveySDK.setDryRun(true)
```

```kotlin
SMGSurveySDK.setDryRun(true)
```

Surveys **still appear**. Trigger outcomes and newly built responses are logged,
but those responses are not enqueued. Normal presentation still records
suppression. Config fetches, tracked screen/events and delivery of responses
already queued can continue; dry run is not an offline mode. Set it back to
`false` when checking real submission and before shipping normal collection.

### Configuration, suppression and queue controls

Both platforms expose these calls with the same spelling:

```swift
SMGSurveySDK.refreshConfiguration()
SMGSurveySDK.resetSessionThrottle()
SMGSurveySDK.pendingResponseCount()
SMGSurveySDK.flushPendingResponses()
```

Refresh is asynchronous and also occurs at initialization, on foreground and on
the configured interval (default 3,600 seconds). Resetting the session throttle
does not clear cooldowns. Flushing requests a queue drain; it does not override
consent or HTTP backpressure. Queue count is a local snapshot, not a delivery
receipt.

To inspect a survey's default presentation, use
`configuredStyle(surveyId: "<your-survey-id>")` in Swift or
`configuredStyle("<your-survey-id>")` in Kotlin. Unknown IDs/no config return
`nil` / `null`.

### Exercise offline behavior

Load a valid config first, disable device networking, complete a normal survey,
and check `pendingResponseCount()`. Restore networking and foreground the app or
call `flushPendingResponses()`, then check the queue and API logs. Use a Stage
project and turn dry run off for this test. There is no `setMockMode` or
`mockReceivedResponses` API in 0.5.4.

## 10. Offline and reliability

Completed responses, and partial responses with at least one answer, are queued
in app-private files before delivery is attempted. Empty dismissals produce no
response. Successfully persisted items survive process restarts; storage failures
are logged. This queue is for survey responses, not a durable screen/event queue.

Delivery is attempted when a response is enqueued, when configuration initializes,
on foreground, when consent is granted and on explicit flush. There is no
connectivity monitor that guarantees an immediate retry when networking returns.

Response delivery uses a stable response ID for idempotency. HTTP 429 pauses
delivery using integer-seconds `Retry-After` (default 60 seconds); the deadline is
in memory, so a restart may retry earlier. Retriable failures keep the queued
response. Permanent rejections (HTTP 400/409/413/415/422) discard it and log the
failure. HTTP 409 is not a successful duplicate acknowledgment; a duplicate is
acknowledged by a 2xx response with the corresponding body status.

A usable cached configuration can support presentation offline. Without a
successful fetch or usable cache, nothing can render. Cooldown history persists;
the session throttle is an in-memory counter and resets with the process.

## 11. API reference

These signatures describe the released 0.5.4 facade. Network work is asynchronous;
snapshot getters do not wait for a fetch. `pendingResponseCount()` synchronously
reads the local queue, so avoid polling it on a hot UI path.

### Swift — `SMGSurveySDK` in `SMGSurveyKit`

```swift
static var sdkVersion: String { get }

static func configure(apiKey: String, projectId: String,
                      environment: SMGEnvironment = .production)
static func trackScreenView(name: String, properties: [String: String] = [:])
static func trackEvent(name: String, properties: [String: String] = [:])
static func presentSurvey(surveyId: String, style: SMGPresentationStyle? = nil,
                          from viewController: UIViewController? = nil)
static func previewSurvey(surveyId: String, style: SMGPresentationStyle? = nil,
                          from viewController: UIViewController? = nil)

static func setTheme(_ theme: SMGTheme)
static func setConsent(granted: Bool)
static func setLocaleOverride(_ localeIdentifier: String?)
static func deleteAllLocalData()
static func setCollectionBaseURL(_ url: URL?)
static func refreshConfiguration()
static func configuredSurveys() -> [SMGSurveyInfo]
static func configuredStyle(surveyId: String) -> SMGPresentationStyle?
static func lastThemeValidationMessages() -> [String]
static func setDryRun(_ enabled: Bool)
static func resetSessionThrottle()
static func pendingResponseCount() -> Int
static func flushPendingResponses()
```

Types used by the facade: `SMGEnvironment` (`.staging`, `.production`),
`SMGPresentationStyle` (`.modal`, `.bottomSheet`, `.banner`), `SMGTheme` and
`SMGSurveyInfo`. `SMGThemeGallery` also supplies five example palettes; these are
demo themes, not a validation of your app's accessibility.

### Objective-C

The framework ships `SMGSurveySDKBridge` and `SMGThemeBridge`; no host Swift shim
is needed. This Stage example belongs in app initialization:

```objc
@import SMGSurveyKit;

[SMGSurveySDKBridge setConsentGranted:hasSurveyConsent];
[SMGSurveySDKBridge configureWithApiKey:@"<staging-api-key>"
                              projectId:@"<staging-project-id>"
                            environment:@"staging"];
```

For production, call `[SMGSurveySDKBridge setCollectionBaseURL:collectionBaseURL]`
before configuration and use production credentials and `@"production"`.

```objc
[SMGSurveySDKBridge trackScreenViewWithName:@"cart"];
[SMGSurveySDKBridge trackEventWithName:@"order_completed"
                            properties:@{@"payment_method": @"apple_pay"}];
[SMGSurveySDKBridge presentSurveyWithId:@"<your-survey-id>" from:self];

SMGThemeBridge *theme = [SMGThemeBridge new];
theme.primary = brandColor;
[SMGSurveySDKBridge setTheme:theme];

[SMGSurveySDKBridge setDryRunEnabled:YES];
[SMGSurveySDKBridge previewSurveyWithId:@"<your-survey-id>"
                                 style:SMGPresentationStyleBridgeDefault
                                  from:self];
```

Presentation also has a `presentSurveyWithId:style:from:` overload. Bridge style
values are `Default`, `Modal`, `BottomSheet` and `Banner`, prefixed with
`SMGPresentationStyleBridge`. `Default` preserves the configured style. The
bridge exposes locale, consent/deletion, theme diagnostics, refresh, session
reset, queue controls and SDK version, but not `configuredSurveys()` in 0.5.4.

### Kotlin — `com.smg.surveysdk.SMGSurveySDK`

```kotlin
val sdkVersion: String

fun configure(context: Context?, apiKey: String?, projectId: String?,
              env: Env? = Env.PRODUCTION)
fun trackScreenView(name: String?, properties: Map<String, String>? = emptyMap())
fun trackEvent(name: String?, properties: Map<String, String>? = emptyMap())
fun presentSurvey(surveyId: String?, style: SMGPresentationStyle? = null)
fun previewSurvey(surveyId: String?, style: SMGPresentationStyle? = null)

fun setTheme(theme: SMGTheme?)
fun setConsent(granted: Boolean)
fun setLocaleOverride(localeTag: String?)
fun deleteAllLocalData()
fun setCollectionBaseUrl(url: String?)
fun refreshConfiguration()
fun configuredSurveys(): List<SMGSurveyInfo>
fun configuredStyle(surveyId: String?): SMGPresentationStyle?
fun lastThemeValidationMessages(): List<String>
fun setDryRun(enabled: Boolean)
fun resetSessionThrottle()
fun pendingResponseCount(): Int
fun flushPendingResponses()
```

Types: `Env` (`STAGING`, `PRODUCTION`), `SMGPresentationStyle` (`MODAL`,
`BOTTOM_SHEET`, `BANNER`), `SMGTheme`/`SMGTheme.Builder`, `SMGColor` and
`SMGSurveyInfo`. Nullable required inputs such as credentials are rejected
internally; supply real values. `setTheme(null)` does not clear a theme; use
`SMGTheme()` or an empty builder.

### Java

Facade methods are static, with shorter overloads for optional arguments. In
`Application.onCreate()`:

```java
SMGSurveySDK.setConsent(hasSurveyConsent);
SMGSurveySDK.configure(this, "<staging-api-key>", "<staging-project-id>", Env.STAGING);
```

As the app is used:

```java
SMGSurveySDK.trackScreenView("cart");
SMGSurveySDK.trackEvent("order_completed",
        Collections.singletonMap("payment_method", "google_pay"));

SMGSurveySDK.setTheme(new SMGTheme.Builder()
        .primary(0xFF003366, 0xFF88AACC)
        .textOnAccent(0xFFFFFFFF)
        .build());

List<SMGSurveyInfo> surveys = SMGSurveySDK.configuredSurveys();
String version = SMGSurveySDK.getSdkVersion();
```

Import the SDK classes from `com.smg.surveysdk` and collection types from
`java.util`. Catalog fields are read through getters such as `getSurveyId()` and
`getHasManualPlacement()`.

## 12. Troubleshooting

| Symptom | Checks |
|---|---|
| No survey appears | Confirm endpoint, credentials, consent, a nonempty config, entitlement, placement rules, cooldown/session limit and a ready host. Preview helps separate configuration/presenter problems from normal trigger gating. |
| `notConfigured` in logs | Production needs an explicit base URL. Setting `nil`/`null` clears networking. Set the endpoint and request a refresh; there is no mock fallback. |
| First screen misses its placement | The first config may still be loading. Track the next real appearance; do not assume a fixed startup delay or automatic replay. |
| `presentSurvey` does nothing | Check that the survey has a manual placement and is not suppressed. Preview bypasses those rules but still needs config, consent and a ready presenter. |
| Android does not present | Configure before the first Activity resumes and use a resumed `ComponentActivity` subclass. Automatic presentation can also be skipped during text entry. |
| Android fails during dependency/build checks | Check compileSdk 36+, compatible AGP/JDK and Kotlin 2.1+ for Kotlin callers. Let Gradle resolve the Maven dependencies; copying only the AAR is insufficient. |
| iOS cannot import the framework | Check the app target's package product, iOS deployment target and Xcode compatibility. The module is `SMGSurveyKit`, not `SMGSurveySDK`. |
| `configuredSurveys` is missing at compile time | Update the dependency to 0.5.4. The Objective-C bridge does not expose this method. |
| Catalog is empty | Config is not available, was deleted or contains no surveys. Check refresh/network logs; reading the catalog does not fetch it. |
| Unexpected sample surveys appear | Check the project, environment and API config. This release does not contain a demo survey fallback. |
| Brand color is wrong | Check host override precedence, color token and light/dark values. On Android use `SMGColor` in the constructor. Inspect diagnostics after presentation; the SDK does not reject colors for contrast. |
| Responses do not arrive | Check dry run/preview, pending queue count, consent, endpoint, auth and API logs. A nonzero queue may be waiting for retry or backpressure; a zero count is not proof of acceptance because permanent rejections are discarded. |

For support, provide your project ID, platform, SDK version, integration steps and
relevant SDK logs. Exclude API keys, personal data and survey answer content from
logs shared for troubleshooting.
