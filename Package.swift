// swift-tools-version: 5.9
// Public distribution package for the SMG App SDK (iOS).
//
// This repository ships only the compiled XCFramework and this manifest — the
// SDK source lives in the private ServiceManagementGroup/mobile-sdk repo.
// Each release tag here points at the artifact attached to that same tag.
import PackageDescription

let package = Package(
    name: "SMGSurveyKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SMGSurveyKit",
            targets: ["SMGSurveyKit"])
    ],
    targets: [
        .binaryTarget(
            name: "SMGSurveyKit",
            url: "https://github.com/ServiceManagementGroup/smg-survey-sdk-ios/releases/download/0.3.0/SMGSurveyKit.xcframework.zip",
            checksum: "bd1e610d4f7d8b6f0b473453c84b76f45fb0b4cc2c13bfa5f29b4cb29f6f248b"
        )
    ]
)
