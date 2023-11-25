import Foundation
import RegexBuilder
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum CodingKeyType: String {
  case camelCase = ".camelCase"
  case snakeCase = ".snakeCase"
  case none = ".none"
}

func extractArgs(from node: AttributeSyntax) -> [String: ExprSyntax] {
  guard case let .argumentList(arguments) = node.arguments else {
    return [:]
  }
  return arguments.reduce(into: [String: ExprSyntax]()) {
    $0[$1.label?.trimmed.description ?? ""] = $1.expression.trimmed
  }
}

extension [String: ExprSyntax] {
  func parse<T>(_ key: String, using block: (ExprSyntax) -> T?) -> T? {
    if let value = self[key] {
      return block(value)
    } else {
      return nil
    }
  }
}

public struct TablePersistMacro: MemberMacro {
  public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    let args = extractArgs(from: node)
    let keyType = args.parse("columns", using: { CodingKeyType(rawValue: $0.description) }) ?? .snakeCase
    guard let tableName = args.parse("table", using: { $0 }) else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Missing table name argument", diagnosticID: .arguments, severity: .error)))
      return []
    }
    let idName = TokenSyntax(stringLiteral: args.parse("idName", using: { $0.description.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }) ?? "id")
    guard let idType = args.parse("idType", using: { $0.description.components(separatedBy: ".").first }) else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "missing idType", diagnosticID: .arguments, severity: .error)))
      return []
    }
    let codingKeyType = args.parse("codable", using: { CodingKeyType(rawValue: $0.description) }) ?? .none
    let trackDirty = args.parse("trackDirty", using: { Bool($0.description) }) ?? true

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

    return try CodingKeysMacro.expansion(of: node, providingMembersOf: declaration,
                                         keyType: keyType,
                                         customId: idName.description,
                                         idType: idType,
                                         codableType: codingKeyType,
                                         in: context) +
      ["static var tableName = \(tableName)",
       DeclSyntax(stringLiteral: "static var idColumn: ColumnName { Self.column(.id) }")] +
    {
      switch (trackDirty, isStruct) {
      case (false, _):
        return []
      case (true, false):
        return ["var dbHash: Int?"]
      case (true, true):
        return [
          "private let _dbHash = OptionalContainer<Int>()",
          """
          var dbHash: Int? {
            get {
               _dbHash.value
            }
            nonmutating set {
               _dbHash.value = newValue
            }
          }
          """
        ]
      }
    }() +
      (isStruct ? [
        "private let _idHolder = OptionalContainer<\(raw: idType)>()",
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
    let args = extractArgs(from: node)
    let codingKeyType = args.parse("codable", using: { CodingKeyType(rawValue: $0.description) }) ?? .none
    let trackDirty = args.parse("trackDirty", using: { Bool($0.description) }) ?? true
    
    var conformingTo = ["TableObject", "FieldSubset"]
    if trackDirty {
      conformingTo.append("TrackingDirty")
    }
    if codingKeyType != .none {
      conformingTo.append("Codable")
    }

    return try [ExtensionDeclSyntax("extension \(type.trimmed): \(raw: conformingTo.joined(separator: ", "))") {}]
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
    return try [ExtensionDeclSyntax("extension \(type.trimmed): FieldSubset") {}]
  }
}

public struct CodingKeysMacro: MemberMacro {
  public static func expansion(of node: AttributeSyntax,
                               providingMembersOf declaration: some DeclGroupSyntax,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
    let args = extractArgs(from: node)
    guard let keyType = args.parse("", using: { CodingKeyType(rawValue: $0.description) }) else {
      context.diagnose(.init(node: node,
                             message: GeneratorDiagnostic(message: "Missing column type (first unlabled) argument", diagnosticID: .arguments, severity: .error)))
      return []
    }
    let codingKeyType = args.parse("codable", using: { CodingKeyType(rawValue: $0.description) }) ?? .none

    return try self.expansion(of: node, providingMembersOf: declaration, keyType: keyType, customId: nil, idType: "", codableType: codingKeyType, in: context)
  }

  public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
                               keyType: CodingKeyType,
                               customId: String?, idType: String, codableType: CodingKeyType,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
    let isStruct: Bool
    switch declaration.kind {
    case .classDecl:
      isStruct = false
      if !declaration.description.contains("final") {
        context.diagnose(.init(node: node,
                               message: GeneratorDiagnostic(message: "@TableObject classes must be declared final", diagnosticID: .arguments, severity: .error)))
        return []
      }
      if customId == nil, declaration.as(ClassDeclSyntax.self)?.inheritanceClause?.inheritedTypes.contains(where: { $0.trimmed.description == "Codable" }) == false {
        context.diagnose(.init(node: node,
                               message: GeneratorDiagnostic(message: "@Column can only be applied to Codable types", diagnosticID: .arguments, severity: .warning)))
      }

    case .structDecl:
      isStruct = true
      if customId == nil, declaration.as(StructDeclSyntax.self)?.inheritanceClause?.inheritedTypes.contains(where: { $0.trimmed.description == "Codable" }) == false {
        context.diagnose(.init(node: node,
                               message: GeneratorDiagnostic(message: "@Column can only be applied to Codable types", diagnosticID: .arguments, severity: .warning)))
      }
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

    var initRowDecl = ["""
    init(row: RowDecoder<Columns>) throws {
    """]

    var encodeRowDecl = ["""
    func encode(row: RowEncoder<Columns>) throws {
    """]

    for (name, type) in members {
      let cleanName = name.description.trimmingCharacters(in: CharacterSet(charactersIn: "` "))
      if type.description != "Children" {
        encodeRowDecl.append("try row.encode(self.\(cleanName), forKey: .\(cleanName))")
      }

      if type.description != "Children" {
        if name.trimmed.description == "id", isStruct {
          initRowDecl.append("self._idHolder.value = try row.decode(\(type).self, forKey: .\(cleanName))")
        } else {
          initRowDecl.append("self.\(cleanName) = try row.decode(\(type.trimmed).self, forKey: .\(cleanName))")
        }
      }
    }
    initRowDecl.append("}")
    encodeRowDecl.append("}")

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
        case .snakeCase: 
          keyValue = raw.snakeCased()
        default: 
          keyValue = raw
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
      DeclSyntax(stringLiteral: initRowDecl.joined(separator: "\n")),
      DeclSyntax(stringLiteral: encodeRowDecl.joined(separator: "\n"))
    ] + (codableType == .none ? [] : try makeCodable(for: node, with: declaration, customId: customId, idType: idType, isStruct: isStruct, keyType: codableType, staticMemberNames: staticMemberNames, in: context))
  }

  static func makeCodable(for node: AttributeSyntax, 
                          with declaration: some DeclGroupSyntax,
                          customId: String?,
                          idType: String,
                          isStruct: Bool,
                          keyType: CodingKeyType,
                          staticMemberNames: [String], 
                           in context: some MacroExpansionContext) throws -> [DeclSyntax] {
    let encodeRegex = Regex {
      "func"
      OneOrMore(.whitespace)
      "encode(to"
      OneOrMore(.any, .reluctant)
      ":"
      ZeroOrMore(.whitespace)
      "Encoder"
    }

    let initRegex = Regex {
      "init(from"
      OneOrMore(.any, .reluctant)
      ":"
      ZeroOrMore(.whitespace)
      "Decoder"
    }

    let membersText = declaration.memberBlock.members.map(\.trimmed.description)
    let hasEncode = membersText.first(where: { $0.firstMatch(of: encodeRegex) != nil }) != nil
    let hasInitFrom = membersText.first(where: { $0.firstMatch(of: initRegex) != nil }) != nil

    let codingMembers = declaration.memberBlock.members
      .flatMap { (memberDeclListItemSyntax: MemberBlockItemSyntax) in
        memberDeclListItemSyntax
          .children(viewMode: .fixedUp)
          .compactMap { $0.as(VariableDeclSyntax.self) }
      }
      .compactMap { (varDecl: VariableDeclSyntax) -> (TokenSyntax, TypeSyntax)? in
        if varDecl.modifiers.description.contains("static") {
          return nil
        } else if varDecl.element(withIdentifier: "CodingKeysIgnored") != nil {
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
      } + [(TokenSyntax(stringLiteral: "id"), TypeSyntax(stringLiteral: idType))]

    var initCodableDecl = ["""
    init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    """]

    var encodeCodableDecl = ["""
    func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    """]

    for (name, type) in codingMembers {
      let cleanName = name.description.trimmingCharacters(in: CharacterSet(charactersIn: "` "))
      if type.is(OptionalTypeSyntax.self) {
        encodeCodableDecl.append("try container.encodeIfPresent(self.\(cleanName), forKey: .\(cleanName))")
      } else if type.description == "Children" {
        encodeCodableDecl.append("try container.encodeIfPresent(self.\(cleanName).loadedValues, forKey: .\(cleanName))")
      } else {
        encodeCodableDecl.append("try container.encode(self.\(cleanName), forKey: .\(cleanName))")
      }

      if type.description != "Children" {
        if name.trimmed.description == "id", isStruct {
          let baseType = type.description.trimmingCharacters(in: CharacterSet(charactersIn: "?"))
          initCodableDecl.append("self._idHolder.value = try container.decode(\(baseType).self, forKey: .\(cleanName))")
        } else if type.is(OptionalTypeSyntax.self) {
          let baseType = type.description.trimmingCharacters(in: CharacterSet(charactersIn: "?"))
          initCodableDecl.append("self.\(cleanName) = try container.decodeIfPresent(\(baseType).self, forKey: .\(cleanName))")
        } else {
          initCodableDecl.append("self.\(cleanName) = try container.decode(\(type.trimmed).self, forKey: .\(cleanName))")
        }
      }
    }
    initCodableDecl.append("}")
    encodeCodableDecl.append("}")

    var codingCases: [String] = try declaration.memberBlock.members.compactMap { member in
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
      if variableDecl.element(withIdentifier: "CodingKeysIgnores") != nil {
        return nil
      } else if staticMemberNames.contains(where: { $0 == property }) {
        return nil
      } else if let element = variableDecl.element(withIdentifier: "Coding") {
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
        case .snakeCase: keyValue = raw.snakeCased()
        default: keyValue = raw
        }
        return raw == keyValue ? "case \(property)" : "case \(property) = \"\(keyValue)\""
      }
    }
    if let customId {
      codingCases = codingCases + [customId == "id" ? "case id" : "case id = \"\(customId)\""]
    }
    guard !codingCases.isEmpty else { return [] }
    let codingKeysDecl: DeclSyntax = """
    enum CodingKeys: String, CodingKey {
        \(raw: codingCases.joined(separator: "\n    "))
    }
    """
    return [codingKeysDecl] + (hasInitFrom ? [] : [DeclSyntax(stringLiteral: initCodableDecl.joined(separator: "\n"))]) + (hasEncode ? [] : [DeclSyntax(stringLiteral: encodeCodableDecl.joined(separator: "\n"))])
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
    let acronymPattern = "([A-Z]+)([A-Z][a-z]|[0-9])"
    let normalPattern = "([a-z0-9])([A-Z])"
    return self.processCamalCaseRegex(pattern: acronymPattern)?
      .processCamalCaseRegex(pattern: normalPattern)?.lowercased() ?? self.lowercased()
  }

  func processCamalCaseRegex(pattern: String) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: count)
    return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
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
