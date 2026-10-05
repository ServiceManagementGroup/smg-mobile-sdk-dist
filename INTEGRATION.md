# Integration guide

Add native surveys to your app in four steps: install, configure, track and test.
This guide covers **[SDK 0.5.5](https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/tag/0.5.5)**,
checked against its source and published binaries on September 30, 2026.

## Before you start

Ask SMG for your API key and project ID, and tell SMG where surveys should
appear (see [how surveys appear](#how-surveys-appear)). For production, also
request the full HTTPS collection base URL.

| iOS | Android |
|---|---|
| iOS 15+, Xcode with SwiftPM | minSdk 26+, compileSdk 36+, JDK 17+ |
| Swift or Objective-C | Kotlin 2.1+ or Java |

On Android, presentation requires an AndroidX `ComponentActivity`;
`AppCompatActivity` and `FragmentActivity` qualify. Your app can use Views or
Compose. Gradle resolves the SDK's AndroidX/Compose dependencies.

## How surveys appear

Your app sends screen views and events with any names you choose. Tell SMG which
screens or events should show a survey; SMG configures those rules and the SDK
checks them on the device. Your app can also show a survey directly from code.

| Option | Your app calls | SMG configures |
|---|---|---|
| **Screen view** | `trackScreenView` when a screen appears | Which screen shows which survey |
| **Event** | `trackEvent` when an action completes | Which event shows which survey |
| **Manual** | `presentSurvey` with a survey ID, wherever your app decides | A manual placement for that survey |

For screen views and events, SMG can also show a survey only when the properties
you send match exact values, such as `payment_method` = `apple_pay`; all
conditions must match. SMG also sets each survey's cooldown and presentation
(bottom sheet, centered modal or banner, and whether users can dismiss it), and
a project limit of automatic surveys per session.

**Screen view and event rules change without an app release.** SMG can switch
the survey a screen or event shows, or change its questions, conditions,
frequency and presentation. Devices apply changes on their next configuration
refresh: at launch, when the app returns to the foreground and periodically, at
an interval set by SMG. Any screen or event your app already sends can start
showing a survey later; one your app does not send yet needs an app release.

**Manual calls keep the survey ID in your app code.** SMG can still edit that
survey without a release, but showing a different survey requires changing the
ID and releasing the app.

## 1. Install

### iOS

In Xcode, choose **File → Add Package Dependencies…**, enter this URL, select
version **0.5.5** and add **SMGSurveyKit** to your app target:

```text
https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist
```

### Android

```kotlin
// settings.gradle.kts — add to dependencyResolutionManagement.repositories
maven { url = uri("https://servicemanagementgroup.github.io/smg-mobile-sdk-dist/maven") }

// app/build.gradle.kts
dependencies {
    implementation("com.smg:smg-surveysdk:0.5.5")
}
```

Keep `google()` and `mavenCentral()` in your repositories. Set `compileSdk` to at
least 36 and `minSdk` to at least 26. Neither platform needs download credentials.
See [build details](API_REFERENCE.md#build-details) for compiler compatibility.

## 2. Configure once at launch

These examples use **Stage**. Replace the credential placeholders, and use your
app's consent state for `hasSurveyConsent`. Consent defaults to granted, so set
it before configuring if your app requires prior consent.

**Swift — at app launch**

```swift
import SMGSurveyKit

SMGSurveySDK.setConsent(granted: hasSurveyConsent)
SMGSurveySDK.configure(
    apiKey: "<staging-api-key>",
    projectId: "<staging-project-id>",
    environment: .staging
)
```

**Kotlin — in `Application.onCreate()`**

```kotlin
import com.smg.surveysdk.Env
import com.smg.surveysdk.SMGSurveySDK

SMGSurveySDK.setConsent(granted = hasSurveyConsent)
SMGSurveySDK.configure(
    context = this,
    apiKey = "<staging-api-key>",
    projectId = "<staging-project-id>",
    env = Env.STAGING,
)
```

Using [Objective-C](API_REFERENCE.md#objective-c) or [Java](API_REFERENCE.md#java)?
Use the equivalent setup in the API reference.

Stage uses the SDK's default collection endpoint.
For **production**, use production credentials and `.production` / `Env.PRODUCTION`,
and set the URL supplied by SMG **before `configure`**:

```swift
SMGSurveySDK.setCollectionBaseURL(collectionBaseURL) // URL supplied by SMG
```

```kotlin
SMGSurveySDK.setCollectionBaseUrl(collectionBaseUrl) // HTTPS URL string supplied by SMG
```

Production has no default endpoint. The SDK has no bundled mock or test surveys.
Configuration loads asynchronously; a call to `configure` does not mean it has
finished. A second call does not switch credentials or project.

## 3. Track screens and actions

Send a screen view when the screen becomes visible and an event when the action
happens. Use any names and properties that describe your app. A survey appears
only when SMG has configured a rule for that screen or event, using the exact
name and property values your app sends, including case.

**Swift**

```swift
SMGSurveySDK.trackScreenView(name: "cart")
SMGSurveySDK.trackEvent(
    name: "order_completed",
    properties: ["payment_method": "apple_pay"]
)
```

**Kotlin**

```kotlin
SMGSurveySDK.trackScreenView("cart")
SMGSurveySDK.trackEvent("order_completed", mapOf("payment_method" to "google_pay"))
```

Avoid sending screen views on every SwiftUI body evaluation or Compose
recomposition. Properties should contain non-PII context: up to 20 keys, with
64 characters per key and 256 per value. Invalid entries are dropped and logged.

### Show a survey from your code

To decide in code when a survey appears, for example from a feedback button or
at the end of a flow, ask SMG for a survey with a **manual placement** and call:

```swift
SMGSurveySDK.presentSurvey(surveyId: "<your-survey-id>", from: viewController)
```

```kotlin
SMGSurveySDK.presentSurvey("<your-survey-id>")
```

Manual calls bypass the session limit but still respect the survey's cooldown
(minimum time between presentations); ask SMG for a cooldown that suits how
often you call it. All normal triggers need consent, a loaded config, an enabled
project and a ready screen; only one survey can be active. Automatic triggers
also skip presentation during text entry.

On first launch, a screen/event can arrive before config loads. It is not replayed
automatically; a later screen visit or event can trigger the survey.

## 4. Test the integration

After config has loaded, inspect the catalog and preview one of its surveys:

**Swift**

```swift
let surveys = SMGSurveySDK.configuredSurveys()
if let survey = surveys.first {
    SMGSurveySDK.previewSurvey(surveyId: survey.surveyId, from: viewController)
}
```

**Kotlin**

```kotlin
val surveys = SMGSurveySDK.configuredSurveys()
surveys.firstOrNull()?.let { survey ->
    SMGSurveySDK.previewSurvey(survey.surveyId)
}
```

The catalog reads current/cached config without fetching it. It is empty before
config is available. Preview bypasses placement rules, entitlement and suppression,
but still needs consent, a configured survey and a ready presenter, with no survey
already active. It does not submit its response or record a cooldown.

Then test a **normal screen/event trigger or manual call**, answer the survey
and confirm receipt with SMG. Keep dry run off for this submission check.

`setDryRun(true)` lets surveys appear but logs new responses instead of enqueueing
them. Config and tracking requests, and previously queued responses, can still
be sent. Set it back to `false` for normal collection.

### Common problems

| Problem | Check |
|---|---|
| Catalog is empty | Credentials, endpoint and configuration-fetch logs. Reading the catalog does not wait for a fetch. |
| Preview works but normal presentation does not | Rules use the exact screen/event names and property values your app sends. Also check project entitlement, consent, cooldown and session limit. Manual calls need a manual placement. |
| An SMG change does not appear | Changes apply after the next configuration refresh: relaunch the app or bring it back to the foreground. A survey shown recently may still be in cooldown on that device. |
| Nothing shows on the first screen | Config may still be loading. Try the next real appearance; there is no fixed readiness delay. |
| Android does not present | Configure in `Application.onCreate()` and use a resumed `ComponentActivity` subclass. |
| Responses do not arrive | Check preview/dry run, consent, endpoint and API logs. Inspect `pendingResponseCount()` and request a retry with `flushPendingResponses()`. |

## Optional app controls

| Need | Use |
|---|---|
| Brand colors or dark-mode overrides | [`setTheme`](API_REFERENCE.md#themes); otherwise the server theme applies |
| App-selected language | [`setLocaleOverride`](API_REFERENCE.md#language); otherwise the app/device locale applies |
| Consent changes or local deletion | [`setConsent` / `deleteAllLocalData`](API_REFERENCE.md#consent-and-local-data) |
| Catalog fields, style overrides or diagnostics | [API reference](API_REFERENCE.md) |
| Offline delivery behavior | [Offline responses](API_REFERENCE.md#offline-responses) |

Consent changes persist. Withholding it gates SDK activity; Android also closes an
active survey, while **iOS leaves it visible and gates completion**. The SDK has no
public survey lifecycle callbacks or answer getters.
