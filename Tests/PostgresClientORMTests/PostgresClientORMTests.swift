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
  lazy var planets = Children(of: self, ofType: Planet.self, parent: .star)
  var otherClass = Classic()
  var accesssedVar:Int  {
  get { 0 }
  set { accesssedVar = newValue }
  }
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
  lazy var planets = Children(of: self, ofType: Planet.self, parent: .star)
  var otherClass = Classic()
  var accesssedVar:Int  {
  get { 0 }
  set { accesssedVar = newValue }
  }
  
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
        case planets
        case otherClass = "other_class"
        case id = "entity_id"
        case currentValue = "current_value"
        case count
        case `protocol`
    }

    typealias Key = CodingKeys

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.otherClass = try container.decode(Classic.self, forKey: .otherClass)
        self.accesssedVar = try container.decode(Int.self, forKey: .accesssedVar)
        self._idHolder.value = try container.decode(String?.self, forKey: .id)
        self.currentValue = try container.decode(Int.self, forKey: .currentValue)
        self.foo = try container.decode(Bool.self, forKey: .foo)
        self.count = try container.decode(Int.self, forKey: .count)
        self.protocol = try container.decode(String.self, forKey: .protocol)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if planets.isLoaded, !(encoder is SQLEncoder) {
            try container.encode(self.planets.values, forKey: .planets)
        }
        try container.encode(self.otherClass, forKey: .otherClass)
        try container.encode(self.accesssedVar, forKey: .accesssedVar)
        try container.encodeIfPresent(self.id, forKey: .id)
        try container.encode(self.currentValue, forKey: .currentValue)
        try container.encode(self.foo, forKey: .foo)
        try container.encode(self.count, forKey: .count)
        try container.encode(self.protocol, forKey: .protocol)
    }

    static var idColumn: ColumnName {
        Self.column(.entity_id)
    }

    @DBHash var dbHash: Int?
}
"""
      assertMacroExpansion(source, expandedSource: expected, macros: testMacros)
  }
}

