// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "PostgresClientORM",
  platforms: [.macOS(.v10_15)],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "PostgresClientORM",
      targets: ["PostgresClientORM"]),
  ],
  dependencies: [
    .package(url: "https://github.com/codewinsdotcom/PostgresClientKit", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
  ],
  targets: [
    .macro(
      name: "CodingKeysGeneratorMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]),
    .target(
      name: "PostgresClientORM",
      dependencies: [
        .product(name: "PostgresClientKit", package: "PostgresClientKit"),
        "CodingKeysGeneratorMacros",
      ]),
    .testTarget(
      name: "PostgresClientORMTests",
      dependencies: ["PostgresClientORM",
                     .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),

      ]),
  ])
