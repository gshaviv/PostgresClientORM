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
//    guard !protocols.isEmpty else {
//      return []
//    }
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "", diagnosticID: .arguments, severity: .error)))
      return []
    }
    guard let rawType = enumDecl.inheritanceClause?.inheritedTypes.as(InheritedTypeListSyntax.self)?.first?.type else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Missing raw value", diagnosticID: .arguments, severity: .error)))
      return []
    }
    guard !type.trimmedDescription.contains(".") else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Can only be applied to file level types", diagnosticID: .arguments, severity: .error)))
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
    return [try ExtensionDeclSyntax("extension \(type.trimmed): PostgresCodable") {
      """
      static var psqlType: PostgresDataType {
        RawValue.psqlType
      }
      """
      """
      static var psqlFormat: PostgresFormat {
        RawValue.psqlFormat
      }
      """
      """
      @inlinable
      func encode(into byteBuffer: inout ByteBuffer, context: PostgresEncodingContext<some PostgresJSONEncoder>) {
        rawValue.encode(into: &byteBuffer, context: context)
      }
      """
      """
      @inlinable
      init(from buffer: inout ByteBuffer, type: PostgresDataType, format: PostgresFormat, context: PostgresDecodingContext<some PostgresJSONDecoder>) throws {
        let raw = try RawValue(from: &buffer, type: type, format: format, context: context)
        if let value = Self(rawValue: raw) {
          self = value
        } else {
          throw PostgresDecodingError.Code.typeMismatch
        }
      }
      """
    }]
  }
}
