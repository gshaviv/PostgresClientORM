// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PostgresClientORM",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PostgresClientORM",
            targets: ["PostgresClientORM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/codewinsdotcom/PostgresClientKit", from: "1.0.0"),
        ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PostgresClientORM",
            dependencies: [
              .product(name: "PostgresClientKit", package: "PostgresClientKit")
            ],
        path: "Sources/PostgresClientORM"),
        .testTarget(
            name: "PostgresClientORMTests",
            dependencies: ["PostgresClientORM"]),
    ]
)
