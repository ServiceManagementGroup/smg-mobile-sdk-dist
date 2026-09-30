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
            url: "https://github.com/ServiceManagementGroup/smg-mobile-sdk-dist/releases/download/0.5.5/SMGSurveyKit.xcframework.zip",
            checksum: "230a26c5fe311c4c5529c3858d8af19cace0bfdc65e574be35ce85d2adcbd9a0"
        )
    ]
)
