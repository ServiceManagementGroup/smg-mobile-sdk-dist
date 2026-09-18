# API reference

Optional controls and signatures for **SDK 0.5.4**. Start with the
[integration guide](INTEGRATION.md) for installation and a working setup.

## Configuration

Call `configure` once per process. Later calls do not switch credentials or
project. Set a production endpoint before configuring; an explicit URL takes
precedence over the environment default.

Changing the endpoint redirects subsequent requests, including queued responses.
Passing `nil` / `null` clears networking but keeps cached config; restore it with
an explicit URL. Use consent to gate SDK activity. `refreshConfiguration()`
requests a fresh config after an endpoint change.

## Themes

The order is host override → server theme → SDK defaults. Set only the values
you need; an empty `SMGTheme` restores server/default values.

```swift
SMGSurveySDK.setTheme(SMGTheme(primary: brandColor, textOnAccent: .white))
```

```kotlin
import com.smg.surveysdk.SMGColor
import com.smg.surveysdk.SMGTheme

SMGSurveySDK.setTheme(SMGTheme(
    primary = SMGColor(0xFF003366.toInt(), 0xFF88AACC.toInt()),
    textOnAccent = SMGColor(0xFFFFFFFF.toInt()),
))
```

Host fields: `primary`, `background`, `surface`, `text`, `accent`, `textOnAccent`,
`textSecondary`, `textPlaceholder`, `border`, `borderControl`, `error`, and `font`.
Spacing, type scale and component layout are fixed by the SDK.

For dark mode, pass a dynamic `UIColor` on iOS. On Android, use `SMGColor(light,
dark)` or `SMGColor.fromResource(R.color.brand)` with `values`/`values-night`
resources; `SMGColor(color)` uses one color in both modes. Java's builder accepts
the same forms. The Kotlin constructor requires `SMGColor`, not a raw integer.

Contrast is checked when server themes are published in Forge. The SDK does not
reject host colors for contrast; check your overrides in both appearances. It
range-checks scalar theme values and exposes server/local diagnostics through
`lastThemeValidationMessages()` after theme resolution.

## Language

```swift
SMGSurveySDK.setLocaleOverride("es-UY")
```

```kotlin
SMGSurveySDK.setLocaleOverride("es-UY")
```

Use a BCP-47 tag. Pass `nil` / `null` to restore the app/device locale. Reapply your
app's override at launch, preferably before configuring; it is not persisted.
Changes refresh config and affect later presentations. Translations must exist
in server content. Config caches are scoped by project, environment and locale.

## Consent and local data

```swift
SMGSurveySDK.setConsent(granted: false)
```

```kotlin
SMGSurveySDK.setConsent(granted = false)
```

Consent defaults to granted and persists after the host changes it. Withholding
it gates new triggers, tracking submissions, config refresh and response delivery.
Queued responses remain stored and can retry when consent is granted again.
Android cancels an active survey; iOS leaves it visible and gates completion while
consent is withheld. Already-sent requests cannot be retracted.

`deleteAllLocalData()` clears cached config, queued responses and suppression,
and cancels active presentation. It keeps credentials and the consent choice and
does not delete server data. Withhold consent first if activity must remain disabled.

The SDK sends answers, screen/event context, supplied metadata, app/OS/SDK versions,
locale and survey timing. It adds no advertising identifiers or cross-app tracking.
Local files/preferences are app-private, without SDK-level encryption. iOS bundles
`PrivacyInfo.xcprivacy`; Android contributes `android.permission.INTERNET`.

## Catalog and presentation

`configuredSurveys()` returns current/cached survey metadata in server order:
`surveyId`, `name`, `presentationStyle` and `hasManualPlacement`. It does not fetch
configuration or check eligibility. It returns an empty list without config.
Swift, Kotlin and Java expose it; the Objective-C bridge does not in 0.5.4.

`presentSurvey` and `previewSurvey` accept an optional style: modal, bottom sheet
or bottom-docked banner. Omitting it uses the configured style. iOS also accepts
`from: UIViewController`; if omitted, the SDK finds a presentation controller.
Android uses the resumed Activity.

Preview skips placement, entitlement, cooldown and session limits. It still needs
initialization, consent, a survey in config, a renderable questionnaire and a ready
presenter, with no other survey active. It records no suppression and enqueues no
response. Other SDK networking remains enabled.

## Diagnostics

| API | Behavior |
|---|---|
| `sdkVersion` | Linked SDK version; Java uses `getSdkVersion()` |
| `refreshConfiguration()` | Requests an asynchronous config refresh; there is no public completion callback |
| `configuredStyle(...)` | Survey's configured style; `nil`/`null` for unknown IDs or missing config |
| `lastThemeValidationMessages()` | Diagnostics from the most recent theme resolution |
| `setDryRun(true)` | Keeps presentation and suppression enabled, but logs new responses instead of enqueueing them; other networking and existing queued delivery can continue |
| `resetSessionThrottle()` | Resets the session count, keeping per-survey cooldowns |
| `pendingResponseCount()` | Local queue count, not a delivery receipt; avoid frequent polling on a UI hot path |
| `flushPendingResponses()` | Requests delivery of queued responses, respecting consent and backpressure |

## Offline responses

A usable cached config supports offline presentation. Completed responses and
partials with at least one answer are persisted before delivery is attempted;
empty dismissals produce no response. Successfully persisted items survive a
process restart. Screen/event tracking is not stored in this durable queue.

Delivery is attempted on enqueue, initialization, foreground, consent grant and
explicit flush. Connectivity recovery alone does not trigger an immediate retry.
HTTP 429 pauses delivery using `Retry-After`; retriable failures keep the response,
while permanent rejections (400/409/413/415/422) discard it and are logged. A zero
queue count does not prove server acceptance.

Cooldown history persists across restarts; the session counter does not. To test
offline delivery, load config, disable networking, answer a normal survey with
dry run off, restore networking and foreground the app or flush explicitly.

## Build details

- **iOS:** the released framework was built with Swift 6.3.3. Use a compatible
  Xcode; the package's Swift tools 5.9 declaration describes the manifest, not
  binary compiler compatibility. Import `SMGSurveyKit` and call `SMGSurveySDK`.
- **Android:** the SDK build uses AGP 8.13.2/Kotlin 2.2.21 and Java 8 bytecode.
  Kotlin callers need Kotlin 2.1+; the build needs JDK 17+, compileSdk 36+ and
  compatible AGP/AndroidX versions. Consume through Maven so Gradle resolves its
  Kotlin, AndroidX, Compose and Material 3 dependencies. No extra SDK keep rules
  are required for ProGuard/R8.

## Swift

`SMGSurveySDK` in module `SMGSurveyKit`:

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

Types: `SMGEnvironment` (`.staging`, `.production`), `SMGPresentationStyle`
(`.modal`, `.bottomSheet`, `.banner`), `SMGTheme` and `SMGSurveyInfo`.

## Objective-C

The framework ships `SMGSurveySDKBridge` and `SMGThemeBridge`. At app launch:

```objc
@import SMGSurveyKit;

[SMGSurveySDKBridge setConsentGranted:hasSurveyConsent];
[SMGSurveySDKBridge configureWithApiKey:@"<staging-api-key>"
                              projectId:@"<staging-project-id>"
                            environment:@"staging"];
```

For production, set `[SMGSurveySDKBridge setCollectionBaseURL:collectionBaseURL]`
before configuring with production credentials and `@"production"`.
In your view controller, track navigation/actions and present from a feedback button:

```objc
[SMGSurveySDKBridge trackScreenViewWithName:@"cart"];
[SMGSurveySDKBridge trackEventWithName:@"order_completed"
                            properties:@{@"payment_method": @"apple_pay"}];
[SMGSurveySDKBridge presentSurveyWithId:@"<your-survey-id>" from:self];

SMGThemeBridge *theme = [SMGThemeBridge new];
theme.primary = brandColor;
[SMGSurveySDKBridge setTheme:theme];
```

For preview:

```objc
[SMGSurveySDKBridge previewSurveyWithId:@"<your-survey-id>"
                                 style:SMGPresentationStyleBridgeDefault
                                  from:self];
```

The style enum uses the prefix `SMGPresentationStyleBridge` with `Default`,
`Modal`, `BottomSheet` or `Banner`. Normal presentation also has a
`presentSurveyWithId:style:from:` overload. For dry run use `setDryRunEnabled:`.
Locale, consent/deletion, refresh, theme diagnostics and queue controls are
available; `configuredSurveys()` is not exposed by this bridge.

## Kotlin

`com.smg.surveysdk.SMGSurveySDK`:

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
`SMGSurveyInfo`. Supply non-null required inputs; `setTheme(null)` is ignored.
Use an empty `SMGTheme()` to clear host overrides.

## Java

Import SDK classes from `com.smg.surveysdk` and collection types from `java.util`.
In `Application.onCreate()`:

```java
SMGSurveySDK.setConsent(hasSurveyConsent);
SMGSurveySDK.configure(this, "<staging-api-key>", "<staging-project-id>", Env.STAGING);
```

For production, call `SMGSurveySDK.setCollectionBaseUrl(collectionBaseUrl)` first,
then configure with production credentials and `Env.PRODUCTION`.
As screens appear or actions complete:

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

Facade methods are static, with shorter overloads for optional parameters.
Read catalog fields through getters such as `getSurveyId()` and
`getHasManualPlacement()`.
