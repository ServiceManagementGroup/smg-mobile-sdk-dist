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
            url: "https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/download/0.5.0/SMGSurveyKit.xcframework.zip",
            checksum: "13535320ec86e96a5d57e84c85209c0a2ac33c29bfb16a673d023cb021e99bb1"
        )
    ]
)
