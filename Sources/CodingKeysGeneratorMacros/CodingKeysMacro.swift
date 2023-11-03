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

    let members = declaration.memberBlock.members
      .flatMap { (memberDeclListItemSyntax: MemberBlockItemSyntax) in
        memberDeclListItemSyntax
          .children(viewMode: .fixedUp)
          .compactMap { $0.as(VariableDeclSyntax.self) }
      }
      .compactMap { (varDecl: VariableDeclSyntax) -> (TokenSyntax, TypeSyntax)? in
        if varDecl.modifiers.description.contains("static") {
          return nil
        } else if varDecl.bindingSpecifier.description.contains("let"), let binding = varDecl.bindings.first?.as(PatternBindingSyntax.self), binding.initializer != nil {
          return nil
        } else if varDecl.bindings.as(PatternBindingListSyntax.self)?.first?.as(PatternBindingSyntax.self)?.accessorBlock?.accessors.as(AccessorDeclListSyntax.self)?.contains(where: { $0.accessorSpecifier.description.hasPrefix("get") }) == true {
          return nil
        }
        guard let syntax = varDecl.bindings.as(PatternBindingListSyntax.self)?.first?.as(PatternBindingSyntax.self), let property = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
          return nil
        }
        
        if let type = syntax.typeAnnotation?.type  {
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
      }

    // varDecl.bindings.as(PatternBindingListSyntax.self)?.first?.as(PatternBindingSyntax.self)?.accessorBlock?.accessors.as(AccessorDeclListSyntax.self)
    
    var initDecl = ["""
    init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    """]
    
    var encodeDecl = ["""
    func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    """]
    
    for (name, type) in members {
      let cleanName = name.description.trimmingCharacters(in: CharacterSet(charactersIn: "` "))
      if  type.is(OptionalTypeSyntax.self) {
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
      if idProperty.name.trimmingCharacters(in: .whitespaces) == name.trimmed.description {
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

    return codingKeys + ["typealias Key = CodingKeys",
                         DeclSyntax(stringLiteral: initDecl.joined(separator: "\n")),
                         DeclSyntax(stringLiteral: encodeDecl.joined(separator: "\n")),
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
                               conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax]
  {
    guard !protocols.isEmpty else {
      return []
    }
    return try [ExtensionDeclSyntax("extension \(type.trimmed): TableObject") {}]
  }
}

public struct CodingKeysMacro: MemberMacro {
  public static func expansion(of node: AttributeSyntax,
                               providingMembersOf declaration: some DeclGroupSyntax,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
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

//struct Delme: Codable {
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
//}
//
//class SQLEncoder {}
