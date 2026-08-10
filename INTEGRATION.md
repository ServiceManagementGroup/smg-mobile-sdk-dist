# Integration guide

How to put the SMG App SDK into an iOS or Android app, from install to a survey on
screen. For the short version, see the [README](README.md).

Applies to **0.4.0**.

**Contents**

1. [How it works](#1-how-it-works)
2. [Requirements](#2-requirements)
3. [Install](#3-install)
4. [Configure](#4-configure)
5. [Instrument your app](#5-instrument-your-app)
6. [When a survey actually appears](#6-when-a-survey-actually-appears)
7. [Theming](#7-theming)
8. [Consent and privacy](#8-consent-and-privacy)
9. [Bring-up toolkit](#9-bring-up-toolkit)
10. [Offline and reliability](#10-offline-and-reliability)
11. [API reference](#11-api-reference)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. How it works

Your app supplies **credentials and instrumentation**. SMG owns **everything else**
— which surveys exist, what they ask, when they fire, how often, and how they look.
All of that is served as a configuration document the SDK fetches and caches; you
change it in the SMG platform, not in your app, and it takes effect without a
release.

Concretely, your app does three things:

```
configure(...)          once at launch
trackScreenView(...)    as the user navigates
trackEvent(...)         when something meaningful happens
```

The SDK decides whether any of those should show a survey, renders it natively
(no webview), and submits the response.

Two guarantees worth stating up front:

- **The SDK never throws into your app.** Every public entry point catches
  internally; a failure is logged and swallowed. A survey that does not show is
  acceptable; a host-app crash is not. You do not need `try`/`catch` around any of
  this.
- **No third-party dependencies** on either platform.

There is no delegate, listener or callback anywhere on the surface: your app cannot
observe that a survey was shown, answered or dismissed, and cannot read the answers.
Responses go to SMG and are read from SMG's reporting. If you need an in-app signal,
say so — it does not exist in 0.4.0.

---

## 2. Requirements

| | iOS | Android |
|---|---|---|
| OS floor | iOS 15+ | minSdk 26 |
| Tooling | Xcode 15+ | AGP 8+ |
| Language | Swift 5.9+, or Objective-C via the bridge | Kotlin **2.1+** if you consume it from Kotlin, or Java 8+ |
| Dependencies added | none | none |
| Permissions added | none | none |

**Kotlin 2.1 is a hard floor for Kotlin callers**, not a recommendation: the AAR
carries Kotlin 2.2 metadata that earlier compilers cannot read. Java callers are
unaffected — a pure-Java host works on Java 8+.

On Android, presenting a survey requires the current Activity to be an AndroidX
`ComponentActivity`. `AppCompatActivity` and `FragmentActivity` both qualify, so
most apps already satisfy this.

---

## 3. Install

Both channels are public and need **no credentials** — no token, no `.netrc`, no
`~/.gradle` entry.

### iOS — Swift Package Manager

In Xcode: **File → Add Package Dependencies…**, then

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

You get a binary XCFramework (device + simulator). The module you import is
**`SMGSurveyKit`**; the class you call is **`SMGSurveySDK`**. They differ on
purpose — a top-level type named after its own module breaks the
library-evolution interface in client builds.

### Android — Gradle

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

That URL is a static Maven layout served over HTTPS — plain files, which is why no
authentication is involved.

No ProGuard/R8 rules are needed. The SDK ships a consumer rules file that is
deliberately empty: it uses no reflection-based serialization, so there is nothing
for you to keep.

---

## 4. Configure

Call this once, as early as you can. It is **non-blocking** — configuration is
fetched in the background and cached; the call returns immediately.

**Swift**

```swift
import SMGSurveyKit

SMGSurveySDK.configure(
    apiKey: "<your key>",
    projectId: "<your project>",
    environment: .production   // or .staging
)
```

**Kotlin**

```kotlin
import com.smg.surveysdk.Env
import com.smg.surveysdk.SMGSurveySDK

SMGSurveySDK.configure(
    context = this,
    apiKey = "<your key>",
    projectId = "<your project>",
    env = Env.PRODUCTION,      // or Env.STAGING
)
```

Note the asymmetry: Android needs a `Context` (any will do — it keeps the
application context), iOS does not. Android's parameter is `env`, not
`environment`.

Get `apiKey` and `projectId` from your SMG implementation engineer. Without a
valid, entitled key the SDK is inert: no surveys, no submissions, no errors thrown
at you. Nothing is validated at the call site — a wrong key produces a failed config
fetch in the log, not an error you can catch.

**`configure` takes effect once.** A second call is ignored and logged, so you
cannot swap credentials at runtime, not even after `deleteAllLocalData()`.

### ⚠️ Point the SDK at a collection endpoint

**In 0.4.0 the SDK talks to a mock transport bundled inside it by default.** If you
integrate and never set a base URL, you will see the SDK's built-in demo surveys —
a fictional restaurant called "SMG Burgers" — rather than your own, and responses
go to an in-app store instead of SMG.

That is almost never what you want, and it looks like a working integration, so it
is worth checking explicitly:

```swift
SMGSurveySDK.setCollectionBaseURL(URL(string: "https://<endpoint from SMG>"))
```

```kotlin
SMGSurveySDK.setCollectionBaseUrl("https://<endpoint from SMG>")
```

Call it **before or right after** `configure`; it takes effect for all subsequent
config fetches and response submissions, including anything already queued.
Passing `nil` / `null` returns to the bundled mock. HTTPS is required (loopback
hosts are exempt so you can point at a local stack during bring-up).

Ask your SMG contact for the endpoint for your environment. A future release will
flip the default so an unconfigured SDK is inert rather than demo-populated.

---

## 5. Instrument your app

### Screen views

```swift
SMGSurveySDK.trackScreenView(name: "cart")
SMGSurveySDK.trackScreenView(name: "cart", properties: ["tier": "gold"])
```

```kotlin
SMGSurveySDK.trackScreenView("cart")
SMGSurveySDK.trackScreenView("cart", mapOf("tier" to "gold"))
```

Use stable, lowercase, machine-readable names — they are matched against
server-side rules. Tracking a screen does **not** imply a survey fires there;
whether it does is a server-side decision.

### Events

```swift
SMGSurveySDK.trackEvent(
    name: "order_completed",
    properties: ["payment_method": "apple_pay", "order_id": "A1234"]
)
```

```kotlin
SMGSurveySDK.trackEvent(
    "order_completed",
    mapOf("payment_method" to "apple_pay", "order_id" to "A1234"),
)
```

Properties are how SMG targets: a placement can require
`payment_method == apple_pay` and fire only on that path. Agree the property names
and their allowed values with SMG — an unexpected value simply fails to match, and
nothing happens.

**Never put personal data in properties.** No emails, phone numbers, card numbers,
free-text the user typed. These are non-PII attributes by contract.

Entries that exceed the limits are **dropped whole, not truncated**, and only the
OS log says so: a key over 64 characters, a value over 256, and beyond 20 keys only
the first 20 alphabetically survive. Keep property sets small and short.

### Manual presentation

For a "Give feedback" button, where the user asked for it:

```swift
SMGSurveySDK.presentSurvey(surveyId: "svy_quick_feedback")
```

```kotlin
SMGSurveySDK.presentSurvey("svy_quick_feedback")
```

**This is not a force-show.** The survey must have a placement configured with
`trigger_type: manual`; a valid survey ID with no manual placement does nothing,
silently. If you want a button to open a specific survey, ask SMG to add that
placement — this is the most common reason a "Give feedback" button appears dead.

Both platforms accept an optional `style` to override the survey's configured
presentation for that one call. On iOS you may also pass an explicit
`from: UIViewController`; omit it and the SDK finds the top-most one.

To render a survey unconditionally while developing, use `previewSurvey` (§9),
which ignores placements and gating entirely.

---

## 6. When a survey actually appears

A trigger is necessary but not sufficient. In order:

| Gate | What it does |
|---|---|
| Consent | Nothing happens if consent was withheld — see §8 |
| One at a time | A survey is never shown over another one |
| Entitlement | The project's entitlement must be active |
| Session throttle | At most one survey per app session |
| Cooldown | A survey that was shown will not return for its configured cooldown, which **survives app restarts** |
| Placement conditions | The screen name / event name / properties must match |

`presentSurvey` **bypasses the session throttle** — the user explicitly asked — but
**still respects the cooldown**, so it will not re-show a survey answered five
minutes ago.

Two consequences worth planning for:

- **A correct integration shows surveys rarely.** Seeing nothing is the expected
  state most of the time. Use dry-run (§9) to see *why* rather than guessing.
- **On the very first launch there is no cached config yet.** A screen tracked in
  the first ~200 ms may not fire its placement until that screen is visited again.
  Every later session is immediate, because the cache is warm.

---

## 7. Theming

SMG configures the full theme server-side — 35 tokens including dark variants,
fonts, radii and opacities. Your app does not need to do anything to be branded.

If you want to override brand colours from the app, `setTheme` exposes **12
tokens**. Anything left unset falls back to the server-side theme, then to SDK
defaults.

**Swift** — all parameters are optional; set only what you mean to change.

```swift
SMGSurveySDK.setTheme(SMGTheme(
    primary: brandColor,
    textOnAccent: .white
))
```

**Kotlin / Java** — use the Builder. The positional constructor would force you to
spell out every preceding token, which is easy to get wrong.

```kotlin
SMGSurveySDK.setTheme(
    SMGTheme.Builder()
        .primary(0xFF003366.toInt())
        .textOnAccent(0xFFFFFFFF.toInt())
        .build()
)
```

Colours are `UIColor` on iOS and packed ARGB `Int` on Android (same as
`android.graphics.Color`).

The 12 tokens: `primary`, `background`, `surface`, `text`, `accent`,
`textOnAccent`, `textSecondary`, `textPlaceholder`, `border`, `borderControl`,
`error`, `font`.

Everything else — spacing, type scale, component minimums, shadows, the disabled
palette — is fixed by the SDK and not themable.

### Validation

Every token you supply is validated for contrast **individually**. One bad colour
no longer discards your whole palette:

- **BLOCK** — the value would make text unreadable. That single token falls back to
  its default and the rejection is logged.
- **WARN** — below target but usable. The value is kept and a warning is logged.

To see what happened during bring-up:

```swift
SMGSurveySDK.lastThemeValidationMessages()   // [String]
```

```kotlin
SMGSurveySDK.lastThemeValidationMessages()   // List<String>
```

An empty list means every token you supplied was accepted. This is worth checking
once after you set a brand theme — a token can be silently swapped for a default
and the survey will still look plausible.

### Dark mode

The server-side theme carries a dark variant for each colour, and the SDK picks it
in dark mode, falling back to the light value and then to its own default.

For a **client override** the two platforms genuinely differ:

- **iOS** resolves your palette twice, once per appearance, and validates each
  against that mode's surfaces. Pass a **dynamic** `UIColor` — an asset-catalogue
  colour set with Any/Dark appearances, or
  `UIColor { $0.userInterfaceStyle == .dark ? darkBrand : lightBrand }` — and each
  mode gets its own value. Pass a **static** `UIColor` and the same value has to
  clear the contrast floor in both modes; if it fails in one, that token reverts to
  the SDK default there.
- **Android** has no per-mode override: `SMGTheme` carries plain ARGB `Int`s, so
  whatever you set applies identically in light and dark. Leave a token unset to
  let the server-side dark variant differentiate it.

Either way, check your brand override in dark mode before shipping — a reverted
token still renders a perfectly plausible survey.

---

## 8. Consent and privacy

### Consent

```swift
SMGSurveySDK.setConsent(granted: false)
```

```kotlin
SMGSurveySDK.setConsent(granted = false)
```

With consent withheld the SDK stops evaluating triggers, stops refreshing
configuration and stops submitting, on both platforms. The flag persists across
launches (`UserDefaults` on iOS, shared preferences on Android).

One platform difference matters if you withdraw consent from a consent-management
screen while a survey could be on screen: **Android dismisses a survey that is
already displayed; iOS leaves it up.** On iOS the survey stays answerable and only
the submission is discarded. If your flow needs the survey gone immediately on iOS,
withdraw consent at a point where one cannot be showing.

**The default is granted.** If your app operates under an opt-in regime, call
`setConsent(granted: false)` before or immediately after `configure` and only flip
it to `true` once the user has agreed. Do not rely on the default.

For a deletion request:

```swift
SMGSurveySDK.deleteAllLocalData()
```

This clears what is on the device — the cached configuration, suppression history
and any queued responses. It does **not** retract responses already submitted to
SMG; route those through your SMG contact.

### What the SDK collects

Survey answers plus their non-PII context: trigger and screen context, the event
properties you supplied, app and OS version, and locale. No advertising
identifiers, no cross-app tracking, no device fingerprinting.

### iOS privacy manifest

The SDK ships its own `PrivacyInfo.xcprivacy`, which aggregates into your app's
App Store privacy report automatically. It declares:

- `NSPrivacyTracking`: **false**, with no tracking domains
- One collected data type: *Other User Content*, **not linked** to identity and
  **not used for tracking**, for App Functionality
- Two required-reason API declarations: `UserDefaults` (CA92.1) and file timestamps
  (C617.1)

In your own App Store submission, declare the survey content your app collects
through the SDK under the same category. The SDK's manifest covers the SDK; it does
not answer for your app.

### Android

The SDK contributes **no permissions** to your merged manifest. If you point it at
a collection endpoint, your app needs `android.permission.INTERNET` — nearly every
app already declares it. For Data Safety, disclose the same categories as above.

---

## 9. Bring-up toolkit

These exist so you can verify the integration without waiting for a real survey to
fire naturally.

### Dry run

The single most useful tool. Nothing is presented and nothing is submitted; instead
every trigger evaluation is logged with the reason it did or did not match.

```swift
SMGSurveySDK.setDryRun(true)
```

```kotlin
SMGSurveySDK.setDryRun(true)
```

You will see lines like `no placement matched` or
`matched placement plc_post_checkout (survey svy_post_checkout)`. This answers "why
is nothing happening" in seconds. **Turn it off before shipping.**

### Preview a survey

Renders a specific survey immediately, ignoring every gate — entitlement, throttle,
cooldown, conditions. It never records suppression and never submits, so previewing
does not burn a cooldown or pollute your data.

```swift
SMGSurveySDK.previewSurvey(surveyId: "svy_quick_feedback")
```

```kotlin
SMGSurveySDK.previewSurvey("svy_quick_feedback")
```

Use preview to check theming and layout; use `presentSurvey` to test the real path.

### Reset the session throttle

Without leaving the app, so you can trigger a second survey in one session:

```swift
SMGSurveySDK.resetSessionThrottle()
```

### Force a configuration refresh

```swift
SMGSurveySDK.refreshConfiguration()
```

Useful right after SMG changes something server-side; otherwise the SDK refreshes
on its own schedule.

### Simulate failure

```swift
SMGSurveySDK.setMockMode(.offline)      // .normal, .offline, .revokedKey
```

Exercises the offline queue and the revoked-key path without touching the network.
This drives the **bundled mock**, so it is a bring-up aid rather than a test against
your real endpoint.

### Inspect the queue

```swift
SMGSurveySDK.pendingResponseCount()   // Int
SMGSurveySDK.flushPendingResponses()  // attempt a drain now
```

### Check the configured presentation

```swift
SMGSurveySDK.configuredStyle(surveyId: "svy_quick_feedback")  // SMGPresentationStyle?
```

Returns what the server config says for that survey, so a debug screen can show the
real default rather than guessing.

---

## 10. Offline and reliability

Completed responses are written to disk **before** any network attempt, so a
response survives losing connectivity, backgrounding, or the process being killed.

The SDK does **not** watch for connectivity returning — there is no reachability
monitor. A queued response is retried at the next app foreground, at the next
`configure`, when consent is granted, or when you call `flushPendingResponses()`
explicitly. In practice that means delivery on the user's next visit to the app
rather than the moment the network comes back.

Configuration is cached the same way: with no network the SDK serves the last
config it fetched, so surveys keep working offline. On a device that has never
fetched successfully, nothing shows.

The cooldown and throttle records persist too — that is what makes "once per user
per period" hold across restarts rather than resetting every launch.

---

## 11. API reference

Every method on the integration surface is fail-safe: none throws, none blocks on
the network. Calls made before `configure` are held or ignored rather than crashing.

The debug helpers in §9 are held to a looser standard — on iOS they are not wrapped
in the same catch-all, and `pendingResponseCount()` blocks briefly on an internal
queue. They are bring-up tools, not something to call on a hot path in production.

### Swift — `SMGSurveySDK` (module `SMGSurveyKit`)

```swift
static var sdkVersion: String { get }

static func configure(apiKey: String, projectId: String, environment: SMGEnvironment = .production)

static func trackScreenView(name: String, properties: [String: String] = [:])
static func trackEvent(name: String, properties: [String: String] = [:])
static func presentSurvey(surveyId: String, style: SMGPresentationStyle? = nil,
                          from viewController: UIViewController? = nil)
static func previewSurvey(surveyId: String, style: SMGPresentationStyle? = nil,
                          from viewController: UIViewController? = nil)

static func setTheme(_ theme: SMGTheme)
static func setConsent(granted: Bool)
static func setLocaleOverride(_ localeIdentifier: String?)   // not persisted; re-apply after each configure
static func deleteAllLocalData()

static func setCollectionBaseURL(_ url: URL?)
static func refreshConfiguration()
static func configuredStyle(surveyId: String) -> SMGPresentationStyle?
static func lastThemeValidationMessages() -> [String]

static func setDryRun(_ enabled: Bool)
static func resetSessionThrottle()
static func setMockMode(_ mode: SMGMockMode)
static func pendingResponseCount() -> Int
static func flushPendingResponses()
static func mockReceivedResponses() -> [String]
```

Public types: `SMGEnvironment { .staging, .production }`,
`SMGPresentationStyle { .modal, .bottomSheet, .banner }`,
`SMGMockMode { .normal, .offline, .revokedKey }`, and `SMGTheme` (12 optional
`UIColor?` tokens plus `font: String?`).

`SMGThemeGallery` is also public — five ready-made palettes used for QA. Two of them
are deliberately rule-violating, to exercise the token fallback, so treat it as a
test fixture rather than a source of brand themes.

### Objective-C

The Swift facade is not directly callable from Objective-C — static methods on a
plain Swift class, plus enums and a struct, none of which bridge. The SDK ships
`SMGSurveySDKBridge` to cover that, so your app needs no shim of its own.

```objc
@import SMGSurveyKit;

[SMGSurveySDKBridge configureWithApiKey:@"<key>"
                              projectId:@"<project>"
                            environment:@"production"];

[SMGSurveySDKBridge trackScreenViewWithName:@"cart"];
[SMGSurveySDKBridge trackEventWithName:@"order_completed"
                            properties:@{@"payment_method": @"apple_pay"}];

[SMGSurveySDKBridge presentSurveyWithId:@"svy_quick_feedback" from:self];

SMGThemeBridge *theme = [SMGThemeBridge new];   // set only what you override
theme.primary = brandColor;
[SMGSurveySDKBridge setTheme:theme];
```

The environment is a string (`@"staging"` / `@"production"`) and theme colours are
`UIColor`. Debug affordances live on `SMGMockModeBridge`.

### Kotlin — `com.smg.surveysdk.SMGSurveySDK`

```kotlin
val sdkVersion: String

fun configure(context: Context?, apiKey: String?, projectId: String?, env: Env? = Env.PRODUCTION)

fun trackScreenView(name: String?, properties: Map<String, String>? = emptyMap())
fun trackEvent(name: String?, properties: Map<String, String>? = emptyMap())
fun presentSurvey(surveyId: String?, style: SMGPresentationStyle? = null)
fun previewSurvey(surveyId: String?, style: SMGPresentationStyle? = null)

fun setTheme(theme: SMGTheme?)
fun setConsent(granted: Boolean)
fun setLocaleOverride(localeTag: String?)   // not persisted; re-apply after each configure
fun deleteAllLocalData()

fun setCollectionBaseUrl(url: String?)
fun refreshConfiguration()
fun configuredStyle(surveyId: String?): SMGPresentationStyle?
fun lastThemeValidationMessages(): List<String>

fun setDryRun(enabled: Boolean)
fun resetSessionThrottle()
fun setMockMode(mode: SMGMockMode?)
fun pendingResponseCount(): Int
fun flushPendingResponses()
fun mockReceivedResponses(): List<String>
```

Public types: `Env { STAGING, PRODUCTION }`,
`SMGPresentationStyle { MODAL, BOTTOM_SHEET, BANNER }`,
`SMGMockMode { NORMAL, OFFLINE, REVOKED_KEY }`, and `SMGTheme` with its `Builder`.

### Java

Everything is `@JvmStatic`, so the call shape is the same:

```java
SMGSurveySDK.configure(this, "<key>", "<project>", Env.PRODUCTION);
SMGSurveySDK.trackScreenView("cart");
SMGSurveySDK.trackEvent("order_completed",
        Collections.singletonMap("payment_method", "apple_pay"));

SMGSurveySDK.setTheme(new SMGTheme.Builder()
        .primary(0xFF003366)
        .textOnAccent(0xFFFFFFFF)
        .build());
```

`@JvmOverloads` generates the shorter arities, so the optional parameters can be
omitted from Java too.

---

## 12. Troubleshooting

**No survey ever appears.**
Turn on dry run (§9) — it prints the reason for every evaluation. The usual causes,
in the order they occur: consent withheld, no config fetched yet (first launch),
the session throttle already spent, a cooldown still running, or the placement
conditions not matching your property values.

**I see surveys about a restaurant I have never heard of.**
That is the bundled mock — you have not set a collection base URL. See §4.

**Nothing happens on first launch, then it works.**
Expected: on the very first run there is no cached config, so a screen tracked in
the first ~200 ms can miss its placement. It resolves on the next visit and every
later session is immediate.

**`presentSurvey` does nothing.**
Most often the survey has no `manual` placement configured — a valid survey ID is
not enough, and the failure is silent. Ask SMG to add one. Failing that, the
cooldown still applies to manual presentation. Confirm with `previewSurvey`, which
ignores placements and gating: if preview shows the survey, the survey itself is
fine and you are looking at a missing placement or a gate.

**Android: nothing presents.**
The current Activity must be an AndroidX `ComponentActivity`
(`AppCompatActivity`/`FragmentActivity` qualify). A plain `android.app.Activity`
does not.

**Android: Kotlin build fails on SDK metadata.**
Kotlin 2.1+ is required for Kotlin consumers of the binary AAR. Java callers are
unaffected.

**My brand colour is not showing.**
Call `lastThemeValidationMessages()`. A token that fails its contrast rule is
replaced with a default (BLOCK) and logged — the survey still renders, which is why
this is easy to miss.

**Responses are not arriving at SMG.**
Check `pendingResponseCount()`. A non-zero count means they are queued locally, so
this is a connectivity or endpoint problem rather than a lost response. Confirm the
base URL from §4 and that mock mode is not left on `.offline`.

Still stuck: contact your SMG implementation engineer with your project ID, the SDK
version (`sdkVersion`), and the dry-run log.
