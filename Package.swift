// swift-tools-version: 5.9
// Public distribution package for the SMG App SDK (iOS).
//
// This repository ships only the compiled XCFramework and this manifest — the
// SDK source is maintained separately.
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
            url: "https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/download/0.5.4/SMGSurveyKit.xcframework.zip",
            checksum: "2899db8c4b06cd1e6b683a6ef2fc520e317de873c7a9222c8ca44e7d1e83a843"
        )
    ]
)
