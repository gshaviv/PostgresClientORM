//
//  File.swift
//
//
//  Created by Guy Shaviv on 16/11/2023.
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct RawRepPCodableMacro: ExtensionMacro {
  public static func expansion(of node: AttributeSyntax,
                               attachedTo declaration: some DeclGroupSyntax,
                               providingExtensionsOf type: some TypeSyntaxProtocol,
                               conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax]
  {
    guard !node.description.contains("rawValue:") else {
      return []
    }
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Must be attached to an extension", diagnosticID: .arguments, severity: .error)))
      return []
    }
    guard let rawType = enumDecl.inheritanceClause?.inheritedTypes.as(InheritedTypeListSyntax.self)?.first?.type else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Missing raw value", diagnosticID: .arguments, severity: .error)))
      return []
    }

    switch rawType.trimmedDescription {
    case "String", "Int", "UInt8", "Int16":
      break
    default:
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "RawValue can only be ne of: String, Int, UInt8, Int16", diagnosticID: .arguments, severity: .error)))
      return []
    }

    return try [ExtensionDeclSyntax("extension \(type.trimmed): FieldSubset") {
      """
      public enum Columns: String, CodingKey {
        case root = ""
      }

      public init(row: RowDecoder<Columns>) throws {
        self.init(rawValue: try row.decode(\(raw: rawType).self, forKey: .root))
      }

      public func encode(row: RowEncoder<Columns>) throws {
        try row.encode(rawValue, forKey: .root)
      }
      """
    }]
  }
}

extension RawRepPCodableMacro: MemberMacro {
  static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    //    guard !protocols.isEmpty else {
    //      return []
    //    }
    guard node.description.contains("rawValue:") else {
      return []
    }
    guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Must be attached to an enum decleration", diagnosticID: .arguments, severity: .error)))
      return []
    }
    let args = extractArgs(from: node)
    guard let rawType = args.parse("rawValue", using: { $0.description.components(separatedBy: ".").first }) else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Missing raw value", diagnosticID: .arguments, severity: .error)))
      return []
    }
    guard extensionDecl.inheritanceClause?.inheritedTypes.as(InheritedTypeListSyntax.self)?.trimmedDescription.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }).contains(where: { $0 == "FieldSubset"}) == true else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "extension must be declared as conforming to FieldSubset", diagnosticID: .arguments, severity: .error)))
      return []
    }

    switch rawType {
    case "String", "Int", "UInt8", "Int16":
      break
    default:
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "RawValue can only be ne of: String, Int, UInt8, Int16", diagnosticID: .arguments, severity: .error)))
      return []
    }
    return [
      """
      public enum Columns: String, CodingKey {
        case root = ""
      }
      """,
      """
      public init(row: RowDecoder<Columns>) throws {
        self.init(rawValue: try row.decode(\(raw: rawType).self, forKey: .root))
      }
      """,
      """
      public func encode(row: RowEncoder<Columns>) throws {
        try row.encode(rawValue, forKey: .root)
      }
      """
    ]
  }
}
