//
//  File.swift
//
//
//  Created by Guy Shaviv on 01/11/2023.
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct IDMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    // Skip declarations other than variables
    guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
      return []
    }
    
    guard varDecl.bindingSpecifier.description.contains("var") else {
      context.diagnose(.init(node: node, message: GeneratorDiagnostic(message: "ID must be a var", diagnosticID: .general, severity: .error)))
      return []
    }

    return [
      """
      get {
         _idHolder.value
      }
      """,
      """
      nonmutating set {
         _idHolder.value = newValue
      }
      """
    ]
  }
}

extension IDMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Skip declarations other than variables
    guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
      return []
    }

    guard var binding = varDecl.bindings.first?.as(PatternBindingSyntax.self), let declaredType = binding.typeAnnotation else {
      context.diagnose(.init(node: node, message: GeneratorDiagnostic(message: "Missing type annoation", diagnosticID: .general, severity: .error)))
      return []
    }
    guard declaredType.type.is(OptionalTypeSyntax.self) else {
      context.diagnose(.init(node: node, message: GeneratorDiagnostic(message: "ID must be declared optional", diagnosticID: .general, severity: .error)))
      return []
    }
    let baseType = declaredType.type.description.trimmingCharacters(in: CharacterSet(charactersIn: "?"))

    binding.pattern = PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("defaultValue")))

    return [
      """
      private let _idHolder = IDHolder<\(raw: baseType)>()
      """
    ]
  }
}
