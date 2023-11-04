@testable import CodingKeysGeneratorMacros
@testable import PostgresClientORM
import PostgresClientKit
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

let testMacros: [String: Macro.Type] = [
    "CodingKeys": CodingKeysMacro.self,
    "CodingKey": CustomCodingKeyMacro.self,
    "CodingKeyIgnored": CodingKeyIgnoredMacro.self,
    "TableObject": TablePersistMacro.self,
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
@TableObject(.snakeCase, table: "entities", idType: String.self, idName: "entity_id", trackDirty: true)
struct Entity {
  var planets = Children(of: self, ofType: Planet.self, parent: .star)
  var otherClass = Classic()
  var accesssedVar:Int  {
  get { 0 }
  set { accesssedVar = newValue }
  }
  @CodingKey(custom: "entity_value")
  let currentValue: Int
  @CodingKeyIgnored
  let foo: Bool
  let count: Int
  let `protocol`: String
}
"""
      let expected = """

struct Entity {
  var planets = Children(of: self, ofType: Planet.self, parent: .star)
  var otherClass = Classic()
  var accesssedVar:Int  {
  get { 0 }
  set { accesssedVar = newValue }
  }
  let currentValue: Int
  let foo: Bool
  let count: Int
  let `protocol`: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case planets
        case otherClass = "other_class"
        case currentValue = "entity_value"
        case count
        case `protocol`
        case id = "entity_id"
    }

    typealias Key = CodingKeys

    static var tableName = "entities"

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.otherClass = try container.decode(Classic.self, forKey: .otherClass)
        self.accesssedVar = try container.decode(Int.self, forKey: .accesssedVar)
        self.currentValue = try container.decode(Int.self, forKey: .currentValue)
        self.foo = try container.decode(Bool.self, forKey: .foo)
        self.count = try container.decode(Int.self, forKey: .count)
        self.protocol = try container.decode(String.self, forKey: .protocol)
        self._idHolder.value = try container.decode(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !(encoder is SQLEncoder) {
            try container.encodeIfPresent(self.planets.loadedValues, forKey: .planets)
        }
        try container.encode(self.otherClass, forKey: .otherClass)
        try container.encode(self.accesssedVar, forKey: .accesssedVar)
        try container.encode(self.currentValue, forKey: .currentValue)
        try container.encode(self.foo, forKey: .foo)
        try container.encode(self.count, forKey: .count)
        try container.encode(self.protocol, forKey: .protocol)
        try container.encode(self.id, forKey: .id)
    }

    static var idColumn: ColumnName {
        Self.column(.id)
    }

    @DBHash var dbHash: Int?

    private let _idHolder = IDHolder<String>()

    var id: String? {
        get {
           _idHolder.value
        }
        nonmutating set {
           _idHolder.value = newValue
        }
    }
}
"""
      assertMacroExpansion(source, expandedSource: expected, macros: testMacros)
  }
  
  func testParentDecoding() throws {
    let decoder = SQLDecoder(columnMap: ["parent": 0], values: [PostgresValue("13")])
    let c = try decoder.decode(Child.self)
    XCTAssert(c.parent.id == 13)
  }
}

@TableObject(keys: .camelCase, table: "xxx", idType: Int.self, trackDirty: false)
struct Papa {
  var c1 = 1
}

struct Child: Decodable {
  var parent: Parent<Papa>
}
