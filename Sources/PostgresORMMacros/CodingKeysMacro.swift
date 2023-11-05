import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct TablePersistMacro: MemberMacro {
  public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    guard case let .argumentList(arguments) = node.arguments,
          arguments.count > 3,
          let generateDbHash = arguments.last?.expression.description,
          let idType = arguments[arguments.index(arguments.startIndex, offsetBy: 2)].expression.description.components(separatedBy: ".").first
    else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Need three arguments: key case type, table name, idType, track dirty", diagnosticID: .arguments, severity: .error)))
      return []
    }
    let tableName = arguments[arguments.index(after: arguments.startIndex)].expression
    let idName: TokenSyntax
    if arguments.count == 5 {
      idName = TokenSyntax(stringLiteral: arguments[arguments.index(arguments.startIndex, offsetBy: 3)].expression.description.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")))
    } else {
      idName = TokenSyntax(stringLiteral: "id")
    }

    let codingKeys = try CodingKeysMacro.expansion(of: node, providingMembersOf: declaration, customId: idName.description, idType: idType, in: context)

    let isStruct: Bool
    switch declaration.kind {
    case .classDecl:
      isStruct = false
      if !declaration.description.contains("final") {
        context.diagnose(.init(node: node,
                               message: GeneratorDiagnostic(message: "@TableObject classes must be declared final", diagnosticID: .arguments, severity: .error)))
        return []
      }
    case .structDecl:
      isStruct = true
    default:
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "@TableObject can be attached only to final class or struct", diagnosticID: .arguments, severity: .error)))
      return []
    }



    return codingKeys + ["static var tableName = \(tableName)",
                         DeclSyntax(stringLiteral: "static var idColumn: ColumnName { Self.column(.id) }")] +
      (generateDbHash == "true" ? [
        "@DBHash var dbHash: Int?"
      ] : []) +
      (isStruct ? [
        "private let _idHolder = IDHolder<\(raw: idType)>()",
        """
        var id: \(raw: idType)? {
        get {
           _idHolder.value
        }
        nonmutating set {
           _idHolder.value = newValue
        }
        }
        """
      ] : [
        "var id: \(raw: idType)?"
      ])
  }
}

extension TablePersistMacro: ExtensionMacro {
  public static func expansion(of node: AttributeSyntax,
                               attachedTo declaration: some DeclGroupSyntax,
                               providingExtensionsOf type: some TypeSyntaxProtocol,
                               conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax]
  {
    guard !protocols.isEmpty else {
      return []
    }
    return try [ExtensionDeclSyntax("extension \(type.trimmed): TableObject") {}]
  }
}

extension CodingKeysMacro: ExtensionMacro {
  public static func expansion(of node: AttributeSyntax,
                               attachedTo declaration: some DeclGroupSyntax,
                               providingExtensionsOf type: some TypeSyntaxProtocol,
                               conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax]
  {
    guard !protocols.isEmpty else {
      return []
    }
    return try [ExtensionDeclSyntax("extension \(type.trimmed): FieldCodable") {}]
  }
}

public struct CodingKeysMacro: MemberMacro {
  public static func expansion(of node: AttributeSyntax,
                               providingMembersOf declaration: some DeclGroupSyntax,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
    try self.expansion(of: node, providingMembersOf: declaration, customId: nil, idType: "", in: context)
  }

  public static func expansion(of node: AttributeSyntax,
                               providingMembersOf declaration: some DeclGroupSyntax,
                               customId: String?, idType: String,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
    guard case let .argumentList(arguments) = node.arguments,
          let keyType = arguments.first?.expression.description
    else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Missing arguments: key case type, track dirty", diagnosticID: .arguments, severity: .error)))
      return []
    }

    let isStruct: Bool
    switch declaration.kind {
    case .classDecl:
      isStruct = false
      if !declaration.description.contains("final") {
        context.diagnose(.init(node: node,
                               message: GeneratorDiagnostic(message: "@TableObject classes must be declared final", diagnosticID: .arguments, severity: .error)))
        return []
      }
    case .structDecl:
      isStruct = true
    default:
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "@TableObject can be attached only to final class or struct", diagnosticID: .arguments, severity: .error)))
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

    let members = declaration.memberBlock.members
      .flatMap { (memberDeclListItemSyntax: MemberBlockItemSyntax) in
        memberDeclListItemSyntax
          .children(viewMode: .fixedUp)
          .compactMap { $0.as(VariableDeclSyntax.self) }
      }
      .compactMap { (varDecl: VariableDeclSyntax) -> (TokenSyntax, TypeSyntax)? in
        if varDecl.modifiers.description.contains("static") {
          return nil
        } else if varDecl.element(withIdentifier: "ColumnIgnored") != nil {
          return nil
        } else if varDecl.bindingSpecifier.description.contains("let"), let binding = varDecl.bindings.first?.as(PatternBindingSyntax.self), binding.initializer != nil {
          return nil
        } else if let accessors = varDecl.bindings.as(PatternBindingListSyntax.self)?.first?.as(PatternBindingSyntax.self)?.accessorBlock?.accessors, accessors.as(AccessorDeclListSyntax.self)?.contains(where: { $0.accessorSpecifier.trimmed.description.hasPrefix("get") }) == true || accessors.as(AccessorDeclListSyntax.self) == nil {
          return nil
        }
        guard let syntax = varDecl.bindings.as(PatternBindingListSyntax.self)?.first?.as(PatternBindingSyntax.self), let property = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
          return nil
        }

        if let type = syntax.typeAnnotation?.type {
          return (property, type.trimmed)
        } else if let initialValue = syntax.initializer?.as(InitializerClauseSyntax.self)?.value {
          let valueDescription = initialValue.description
          if valueDescription.hasPrefix("\"") {
            return (property, "String")
          }
          let valueChars = CharacterSet(charactersIn: valueDescription)
          if CharacterSet(charactersIn: "-0123456789_").isSuperset(of: valueChars) {
            return (property, "Int")
          }
          if CharacterSet(charactersIn: "-0123456789.e_").isSuperset(of: valueChars) {
            return (property, "Double")
          }
          if valueDescription.trimmingCharacters(in: .whitespaces) == "false" || valueDescription.trimmingCharacters(in: .whitespaces) == "true" {
            return (property, "Bool")
          }
          if let call = initialValue.as(FunctionCallExprSyntax.self)?.calledExpression.description, call[call.startIndex].isUppercase {
            return (property, TypeSyntax(stringLiteral: call))
          }
          context.diagnose(.init(node: node, message: GeneratorDiagnostic(message: "Missing type annotation", diagnosticID: .general, severity: .error)))
          fatalError()
        }
        return nil
      } + (customId != nil ? [(TokenSyntax(stringLiteral: "id"), TypeSyntax(stringLiteral: idType))] : [])

    var initDecl = ["""
    init(row: RowReader) throws {
    let container = try row.container(keyedBy: Columns.self)
    """]

    var encodeDecl = ["""
    func encode(row: RowWriter) throws {
    var container = row.container(keyedBy: Columns.self)
    """]

    for (name, type) in members {
      let cleanName = name.description.trimmingCharacters(in: CharacterSet(charactersIn: "` "))
      if type.is(OptionalTypeSyntax.self) {
        encodeDecl.append("try container.encodeIfPresent(self.\(cleanName), forKey: .\(cleanName))")
      } else if type.description == "Children" {
        encodeDecl.append("if !(encoder is SQLEncoder) {")
        encodeDecl.append("try container.encodeIfPresent(self.\(cleanName).loadedValues, forKey: .\(cleanName))")
        encodeDecl.append("}")
      } else {
        encodeDecl.append("try container.encode(self.\(cleanName), forKey: .\(cleanName))")
      }

      if type.description == "Children" {
        continue
      }
      if name.trimmed.description == "id", isStruct {
        let baseType = type.description.trimmingCharacters(in: CharacterSet(charactersIn: "?"))
        initDecl.append("self._idHolder.value = try container.decode(\(baseType).self, forKey: .\(cleanName))")
      } else if type.is(OptionalTypeSyntax.self) {
        let baseType = type.description.trimmingCharacters(in: CharacterSet(charactersIn: "?"))
        initDecl.append("self.\(cleanName) = try container.decodeIfPresent(\(baseType).self, forKey: .\(cleanName))")
      } else {
        initDecl.append("self.\(cleanName) = try container.decode(\(type.trimmed).self, forKey: .\(cleanName))")
      }
    }
    initDecl.append("}")
    encodeDecl.append("}")

    var cases: [String] = try declaration.memberBlock.members.compactMap { member in
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
      if variableDecl.element(withIdentifier: "ColumnIgnored") != nil {
        return nil
      } else if staticMemberNames.contains(where: { $0 == property }) {
        return nil
      } else if let element = variableDecl.element(withIdentifier: "Column") {
        guard let customKeyName = element.customKey() else {
          let diagnostic = Diagnostic(node: Syntax(node), message: CodingKeysDiagnostic())
          context.diagnose(diagnostic)
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
    if let customId {
      cases = cases + [customId == "id" ? "case id" : "case id = \"\(customId)\""]
    }
    guard !cases.isEmpty else { return [] }
    let casesDecl: DeclSyntax = """
    enum Columns: String, CodingKey, CaseIterable {
        \(raw: cases.joined(separator: "\n    "))
    }
    """
    return [
      casesDecl,
      DeclSyntax(stringLiteral: initDecl.joined(separator: "\n")),
      DeclSyntax(stringLiteral: encodeDecl.joined(separator: "\n"))
    ]
  }
}

public struct CustomCodingKeyMacro: PeerMacro {
  public static func expansion(of node: AttributeSyntax,
                               providingPeersOf declaration: some DeclSyntaxProtocol,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
    []
  }
}

public struct CodingKeyIgnoredMacro: PeerMacro {
  public static func expansion(of node: AttributeSyntax,
                               providingPeersOf declaration: some DeclSyntaxProtocol,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
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

// struct Delme: Codable {
//  var id: Int
//  var other: UUID?
//  var `protocol`: Int = 43
//
//  init(from decoder: Decoder) throws {
//    let container = try decoder.container(keyedBy: CodingKeys.self)
//    self.id = try container.decode(Int.self, forKey: .id)
//    self.other = try container.decodeIfPresent(UUID.self, forKey: .other)
//    self.protocol = try container.decode(Int.self, forKey: .protocol)
//  }
//
//  enum CodingKeys: CodingKey {
//    case id
//    case other
//    case `protocol`
//  }
//
//  func encode(to encoder: Encoder) throws {
//    var container = encoder.container(keyedBy: CodingKeys.self)
//    try container.encode(self.id, forKey: .id)
//    try container.encodeIfPresent(self.other, forKey: .other)
//    try container.encode(self.protocol, forKey: .protocol)
//    if !(encoder is SQLEncoder), true {
//
//    }
//  }
// }
//
// class SQLEncoder {}
