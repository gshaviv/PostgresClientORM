@testable import PostgresORMMacros
@testable import PostgresClientORM
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import PostgresNIO

let testMacros: [String: Macro.Type] = [
    "Columns": CodingKeysMacro.self,
    "Column": CustomCodingKeyMacro.self,
    "ColumnIgnored": CodingKeyIgnoredMacro.self,
    "TableObject": TablePersistMacro.self,
    "PostgresCodable": RawRepPCodableMacro.self,
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

    init(row: RowDecoder<Columns>) throws {
        self.galaxy = try row.decode(Parent<Galaxy>.self, forKey: .galaxy)
        self.otherClass = try row.decode(Classic.self, forKey: .otherClass)
        self.currentValue = try row.decode(Int.self, forKey: .currentValue)
        self.count = try row.decode(Int.self, forKey: .count)
        self.protocol = try row.decode(String.self, forKey: .protocol)
        self._idHolder.value = try row.decode(String.self, forKey: .id)
    }

    func encode(row: RowEncoder<Columns>) throws {
        try row.encode(self.galaxy, forKey: .galaxy)
        try row.encode(self.otherClass, forKey: .otherClass)
        try row.encode(self.currentValue, forKey: .currentValue)
        try row.encode(self.count, forKey: .count)
        try row.encode(self.protocol, forKey: .protocol)
        try row.encode(self.id, forKey: .id)
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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.galaxy = try container.decode(Parent<Galaxy>.self, forKey: .galaxy)
        self.otherClass = try container.decode(Classic.self, forKey: .otherClass)
        self.currentValue = try container.decode(Int.self, forKey: .currentValue)
        self.foo = try container.decode(Bool.self, forKey: .foo)
        self.count = try container.decode(Int.self, forKey: .count)
        self.protocol = try container.decode(String.self, forKey: .protocol)
        self._idHolder.value = try container.decode(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
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
  


  func testInt64() throws {
    let query = try Test.select().where({
      Test.idColumn == 23
    })
    XCTAssertEqual(query.sqlString, "SELECT * FROM xxx WHERE id = $1")
    XCTAssertEqual(query.bindings.count, 1)
  }
  
  func testNilWhere() throws {
    XCTAssertEqual("\(ColumnName("col") == NULL)", "col IS NULL", "Failed")
  }
}

@TableObject(columns: .snakeCase, table: "xxx", idType: Int64.self)
struct Test {
  var variable: Int
}
