// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Flutter plugins that support Swift Package Manager must provide a Package.swift
// so Xcode can resolve the plugin without CocoaPods when the host app uses SPM.
//
// Native Twilio SDKs (TwilioVideo, TwilioVoice) are linked via CocoaPods in the
// host app's Podfile when SPM is not available for those dependencies.
// This Package.swift declares only the Flutter plugin wrapper sources.

import PackageDescription

let package = Package(
    name: "flutter_twilio_commkit_ios",
    platforms: [
        .iOS("14.0"),
    ],
    products: [
        .library(
            name: "flutter-twilio-commkit-ios",
            targets: ["flutter_twilio_commkit_ios"],
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_twilio_commkit_ios",
            dependencies: [],
            path: "ios/Classes",
            // Flutter framework is provided by the host app's build system.
            // Twilio SDKs are linked via CocoaPods (see ios/flutter_twilio_commkit_ios.podspec).
            publicHeadersPath: "include",
        ),
    ]
)

