// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "MimeLib",
    products: [
        .library(
            name: "MimeLib",
            targets: ["MimeLib"]
        ),
    ],
    targets: [
        .target(
            name: "MimeLib",
            path: "Sources"
         ),
    ]
)
