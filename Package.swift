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
            url: "https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/download/0.5.2/SMGSurveyKit.xcframework.zip",
            checksum: "f9c289937e91f5d011398f18681fa6167ffe7918d0d7f3e60c3df175ee673d06"
        )
    ]
)
