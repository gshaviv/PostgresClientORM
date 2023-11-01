import CodingKeysGeneratorMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

let testMacros: [String: Macro.Type] = [
    "CodingKeys": CodingKeysMacro.self,
    "CodingKey": CustomCodingKeyMacro.self,
    "CodingKeyIgnored": CodingKeyIgnoredMacro.self,
    "TablePersist": TablePersistMacro.self,
    "ID": IDMacro.self
]

final class CodingKeysGeneratorTests: XCTestCase {
    func testCodingKeysMacros() {
        let source = """
@CodingKeys
struct Entity {
    @CodingKey(custom: "entity_id")
    let id: String
    let currentValue: Int
    @CodingKeyIgnored
    let foo: Bool
    let count: Int
    let `protocol`: String
}
"""
        let expected = """

struct Entity {
    let id: String
    let currentValue: Int
    let foo: Bool
    let count: Int
    let `protocol`: String

    enum CodingKeys: String, CodingKey {
        case id = "entity_id"
        case currentValue = "current_value"
        case count
        case `protocol`
    }
}
"""
        assertMacroExpansion(source, expandedSource: expected, macros: testMacros)
    }
  
  func testTablePersistMacros() {
      let source = """
@TablePersist(.snakeCase, trackDirty: true)
struct Entity {
  @CodingKey(custom: "entity_id")
  @ID var id: String?
  let currentValue: Int
  @CodingKeyIgnored
  let foo: Bool
  let count: Int
  let `protocol`: String
}
"""
      let expected = """

struct Entity {
  
  var id: String? {
      get {
         _idHolder.value
      }
      nonmutating set {
         _idHolder.value = newValue
      }
  }

  private let _idHolder = IDHolder<String>()
  let currentValue: Int
  let foo: Bool
  let count: Int
  let `protocol`: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id = "entity_id"
        case currentValue = "current_value"
        case count
        case `protocol`
    }

    typealias Key = CodingKeys

    static var idColumn: ColumnName {
        Self.column(.entity_id)
    }

    @DBHash var dbHash: Int?
}
"""
      assertMacroExpansion(source, expandedSource: expected, macros: testMacros)
  }
}

