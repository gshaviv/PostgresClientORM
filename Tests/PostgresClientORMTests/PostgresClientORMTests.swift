@testable import PostgresORMMacros
@testable import PostgresClientORM
import PostgresClientKit
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

let testMacros: [String: Macro.Type] = [
    "Columns": CodingKeysMacro.self,
    "Column": CustomCodingKeyMacro.self,
    "ColumnIgnored": CodingKeyIgnoredMacro.self,
    "TableObject": TablePersistMacro.self,
    "ID": IDMacro.self,
]

final class CodingKeysGeneratorTests: XCTestCase {
    func testColumnsMacros() {
        let source = """
@Columns(.snakeCase)
final class Entity: Codable {
    let currentValue: Int
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
@TableObject(columns: .snakeCase, table: "entities", idType: String.self, idName: "entity_id", codable: .camelCase)
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
  @Column(name: "entity_value")
  let currentValue: Int
  @ColumnIgnored
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
        case currentValue = "entity_value"
        case count
        case `protocol`
        case id = "entity_id"
    }

    init(row: RowReader) throws {
        let container = try row.container(keyedBy: Columns.self)
        self.galaxy = try container.decode(Parent<Galaxy>.self, forKey: .galaxy)
        self.otherClass = try container.decode(Classic.self, forKey: .otherClass)
        self.currentValue = try container.decode(Int.self, forKey: .currentValue)
        self.count = try container.decode(Int.self, forKey: .count)
        self.protocol = try container.decode(String.self, forKey: .protocol)
        self._idHolder.value = try container.decode(String.self, forKey: .id)
    }

    func encode(row: RowWriter) throws {
        var container = row.container(keyedBy: Columns.self)
        try container.encode(self.galaxy, forKey: .galaxy)
        try container.encode(self.otherClass, forKey: .otherClass)
        try container.encode(self.currentValue, forKey: .currentValue)
        try container.encode(self.count, forKey: .count)
        try container.encode(self.protocol, forKey: .protocol)
        try container.encode(self.id, forKey: .id)
    }

    enum CodingKeys: String, CodingKey {
        case planets
        case galaxy
        case otherClass
        case currentValue
        case foo
        case count
        case `protocol`
        case id = "entity_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Columns.self)
        self.galaxy = try container.decode(Parent<Galaxy>.self, forKey: .galaxy)
        self.otherClass = try container.decode(Classic.self, forKey: .otherClass)
        self.currentValue = try container.decode(Int.self, forKey: .currentValue)
        self.foo = try container.decode(Bool.self, forKey: .foo)
        self.count = try container.decode(Int.self, forKey: .count)
        self.protocol = try container.decode(String.self, forKey: .protocol)
        self._idHolder.value = try container.decode(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Columns.self)
        try container.encodeIfPresent(self.planets.loadedValues, forKey: .planets)
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

    private let _dbHash = OptionalContainer<Int>()

    var dbHash: Int? {
      get {
         _dbHash.value
      }
      nonmutating set {
         _dbHash.value = newValue
      }
    }

    private let _idHolder = OptionalContainer<String>()

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
  
  func testNilWhere() throws {
    XCTAssertEqual("\(ColumnName("col") == NULL)", "col IS NULL", "Failed")
  }
}

