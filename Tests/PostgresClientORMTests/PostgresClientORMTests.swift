@testable import PostgresORMMacros
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
@TableObject(.snakeCase, table: "entities", idType: String.self, idName: "entity_id")
struct Entity {
  var planets = Children(of: self, ofType: Planet.self, parent: .star)
  var galaxy: Parent<Galaxy>
  var otherClass = Classic()
  var accesssedVar: Int  {
  get {
    0
  }
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
  var galaxy: Parent<Galaxy>
  var otherClass = Classic()
  var accesssedVar: Int  {
  get {
    0
  }
  set { accesssedVar = newValue }
  }
  let currentValue: Int
  let foo: Bool
  let count: Int
  let `protocol`: String

    enum Columns: String, CodingKey, CaseIterable {
        case planets
        case galaxy
        case otherClass = "other_class"
        case currentValue = "current_value"
        case foo
        case count
        case `protocol`
        case id = "entity_id"
    }

    init(row: RowReader) throws {
        let container = try row.container(keyedBy: Columns.self)
        self.galaxy = try container.decode(Parent<Galaxy>.self, forKey: .galaxy)
        self.otherClass = try container.decode(Classic.self, forKey: .otherClass)
        self.currentValue = try container.decode(Int.self, forKey: .currentValue)
        self.foo = try container.decode(Bool.self, forKey: .foo)
        self.count = try container.decode(Int.self, forKey: .count)
        self.protocol = try container.decode(String.self, forKey: .protocol)
        self._idHolder.value = try container.decode(String.self, forKey: .id)
    }

    func encode(row: RowWriter) throws {
        var container = row.container(keyedBy: Columns.self)
        try container.encode(self.galaxy, forKey: .galaxy)
        try container.encode(self.otherClass, forKey: .otherClass)
        try container.encode(self.currentValue, forKey: .currentValue)
        try container.encode(self.foo, forKey: .foo)
        try container.encode(self.count, forKey: .count)
        try container.encode(self.protocol, forKey: .protocol)
        try container.encode(self.id, forKey: .id)
    }

    static var tableName = "entities"

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
  
  
  @TableObject(columns: .snakeCase, table: "xxx", idType: Int64.self)
  struct Test {
    var variable: Int
  }

  func testInt64() throws {
    let sql = Test.select().where({
      Test.idColumn == 23
    }).sqlString
    XCTAssertEqual(sql, "SELECT * FROM xxx WHERE id = 23")
  }
}

