import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct TablePersistMacro: MemberMacro {
  public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    guard case let .argumentList(arguments) = node.arguments,
          arguments.count == 2,
          let generateDbHash = arguments.last?.expression.description
    else {
      context.diagnose(.init(node: node, 
                             message: GeneratorDiagnostic(message: "Need two arguments: key case type, track dirty", diagnosticID: .arguments, severity: .error)))
      return []
    }
    
    let codingKeys = try CodingKeysMacro.expansion(of: node, providingMembersOf: declaration, in: context)
    let idPropertyList: [(id: String, name: String)] = try declaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
      guard variableDecl.element(withIdentifier: "ID") != nil else { return nil }
      guard let pname = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.description else { return nil }
      if let element = variableDecl.element(withIdentifier: "CodingKey") {
        guard let customKeyName = element.customKey() else {
          let diagnostic = Diagnostic(node: Syntax(node), message: CodingKeysDiagnostic())
          throw DiagnosticsError(diagnostics: [diagnostic])
        }
        return (id: customKeyName.description.trimmingCharacters(in: CharacterSet(charactersIn: "\"")), name: pname)
      }
      return (id: pname, name: pname)
    }
    guard let idProperty = idPropertyList.first else { return [] }
    return codingKeys + ["typealias Key = CodingKeys",
                         DeclSyntax(stringLiteral: "static var idColumn: ColumnName { Self.column(.\(idProperty.id.trimmingCharacters(in: .whitespaces))) }")] +
    (generateDbHash == "true" ? [
      "@DBHash var dbHash: Int?"
    ] : [])
  }
}

 extension TablePersistMacro: ExtensionMacro {
  public static func expansion(of node: AttributeSyntax,
                               attachedTo declaration: some DeclGroupSyntax,
                               providingExtensionsOf type: some TypeSyntaxProtocol,
                               conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
    guard !protocols.isEmpty else {
      return []
    }
    return [try ExtensionDeclSyntax("extension \(type.trimmed): TableObject") {}]
  }
 }

public struct CodingKeysMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard case let .argumentList(arguments) = node.arguments,
          let keyType = arguments.first?.expression.description
    else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Missing arguments: key case type, track dirty", diagnosticID: .arguments, severity: .error)))
      return []
    }

    let staticMemberNames: [String] = declaration.memberBlock.members
      .flatMap { (memberDeclListItemSyntax: MemberBlockItemSyntax) in
        memberDeclListItemSyntax
          .children(viewMode: .fixedUp)
          .compactMap { $0.as(VariableDeclSyntax.self) }
      }
      .compactMap { (variableDeclSyntax: VariableDeclSyntax) in
        guard variableDeclSyntax.hasStaticModifier else {
          return nil
        }
        return variableDeclSyntax.bindings
          .compactMap { (patternBindingSyntax: PatternBindingSyntax) in
            patternBindingSyntax.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
          }
          .first
      }

    let cases: [String] = try declaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
      guard let property = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
      else {
        return nil
      }
      if member.description.contains("{") {
        let description = member.description
        guard description.contains("didSet") || description.contains("willSet") || description.contains("didSet") else {
          return nil
        }
      }
      if variableDecl.element(withIdentifier: "CodingKeyIgnored") != nil {
        return nil
      } else if staticMemberNames.contains(where: { $0 == property }) {
        return nil
      } else if let element = variableDecl.element(withIdentifier: "CodingKey") {
        guard let customKeyName = element.customKey() else {
          let diagnostic = Diagnostic(node: Syntax(node), message: CodingKeysDiagnostic())
          throw DiagnosticsError(diagnostics: [diagnostic])
        }
        return property == "\(customKeyName)" ? "case \(property)" : "case \(property) = \(customKeyName)"
      } else {
        let raw = property.dropBackticks()
        let keyValue: String
        switch keyType {
        case ".snakeCase": keyValue = raw.snakeCased()
        default: keyValue = raw
        }
        return raw == keyValue ? "case \(property)" : "case \(property) = \"\(keyValue)\""
      }
    }
    guard !cases.isEmpty else { return [] }
    let casesDecl: DeclSyntax = """
    enum CodingKeys: String, CodingKey, CaseIterable {
        \(raw: cases.joined(separator: "\n    "))
    }
    """
    return [casesDecl]
  }
}

public struct CustomCodingKeyMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}

public struct CodingKeyIgnoredMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}

struct CodingKeysDiagnostic: DiagnosticMessage {
  let message: String = "Empty argument"
  let diagnosticID: SwiftDiagnostics.MessageID = .init(domain: "CodingKeysGenerator", id: "emptyArgument")
  let severity: SwiftDiagnostics.DiagnosticSeverity = .error
}

private extension String {
  func dropBackticks() -> String {
    count > 1 && first == "`" && last == "`" ? String(dropLast().dropFirst()) : self
  }

  func snakeCased() -> String {
    reduce(into: "") { $0.append(contentsOf: $1.isUppercase ? "_\($1.lowercased())" : "\($1)") }
  }
}

private extension VariableDeclSyntax {
  var hasStaticModifier: Bool {
    self.modifiers.children(viewMode: .fixedUp)
      .compactMap { syntax in
        syntax.as(DeclModifierSyntax.self)?
          .children(viewMode: .fixedUp)
          .contains { syntax in
            switch syntax.as(TokenSyntax.self)?.tokenKind {
            case .keyword(.static):
              return true
            default:
              return false
            }
          }
      }
      .contains(true)
  }

  var hasLeftBrace: Bool {
    self.modifiers.children(viewMode: .fixedUp)
      .compactMap { syntax in
        syntax.as(DeclModifierSyntax.self)?
          .children(viewMode: .fixedUp)
          .contains { syntax in
            switch syntax.as(TokenSyntax.self)?.tokenKind {
            case .leftBrace:
              return true
            default:
              return false
            }
          }
      }
      .contains(true)
  }
}

private extension VariableDeclSyntax {
  func element(
    withIdentifier macroName: String
  ) -> AttributeListSyntax.Element? {
    attributes.first {
      $0.as(AttributeSyntax.self)?
        .attributeName
        .as(IdentifierTypeSyntax.self)?
        .description
        .trimmingCharacters(in: .whitespaces) == macroName
    }
  }
}

private extension AttributeListSyntax.Element {
  func customKey() -> ExprSyntax? {
    self
      .as(AttributeSyntax.self)?
      .arguments?
      .as(LabeledExprListSyntax.self)?
      .first?
      .expression
  }
}
