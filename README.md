# SMG App SDK

Native in-app surveys for iOS and Android. Your app supplies credentials, consent
and screen/event tracking. SMG configuration controls the surveys and when they
appear; the SDK renders them and sends responses to the collection API.

This repository distributes the compiled SDK. The source is maintained privately
by SMG.

**Documented version: [0.5.4](https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/tag/0.5.4).**

| | iOS | Android |
|---|---|---|
| Install with | Swift Package Manager | Gradle / Maven |
| Artifact | `SMGSurveyKit.xcframework` | `com.smg:smg-surveysdk:0.5.4` |
| Minimum OS | iOS 15 | Android API 26 |
| Host languages | Swift, Objective-C | Kotlin, Java |

Artifact downloads require no credentials. API access requires a provisioned key
and project; production also requires an explicit collection endpoint.

**Start with the [integration guide](INTEGRATION.md): install → configure → track → test.**

For optional controls and language-specific details, see the
[API reference](API_REFERENCE.md), including [Objective-C](API_REFERENCE.md#objective-c)
and [Java](API_REFERENCE.md#java).

For support, contact your SMG implementation engineer with the project ID, SDK
version and relevant SDK logs. Leave credentials and personal/answer data out of
shared logs.
