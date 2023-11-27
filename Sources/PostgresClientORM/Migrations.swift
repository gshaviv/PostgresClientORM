//
//  File.swift
//
//
//  Created by Guy Shaviv on 28/10/2023.
//

import Foundation

/// Perform database migrations
///
/// Create an instance of the Migrations class, add the various migrations steps with the ``add`` function which receives a string with the migration step name and a block to execute. Finally call the ``perform`` func to perform the migrations.
/// The class will create a `_migrations` table if one does not exist to track which migrations were executed alrready and starts executing the migration steps in the order they were added starting from the first step that wasn't executed yet. `.update(:)` the arugment being the new column type
///
/// Example:
///  ```Swift
///    func migrate() async throws {
///          let migrations = Migrations()
///
///          migrations.add("v1") {
///            try await table("t1") {
///                column("id", type: .uuid).primaryKey()
///                column("count", type: .int).notNull()
///            }
///            .create()
///          }
///
///          migrations.add("v2") {
///            try await table("t1") {
///                 column("count").drop()
///                 column("name, type: .string)
///            }
///            .update()
///          }
///
///          try await migrations.perform()
///    }
///  ```
///
///  The modifiers that can be applied on a table are: `.create()`, `.drop()` and `.update()`.
///
///  The modifiers that can be applied on a column in a table are: `.primaryKey()`, `.notNull()`, `.defaultValue(:)` (with the default value given as the SQL string for that value,  `rename(:)` the argument being the new column name, `.unique()` sets a unique contraint on the column, `references(table:column:onDelete)` make the column a foreign key to specified column in specified talbe. the onDelete argument is what to do on delete (e.g. cascade, or not allow, etc)
///
/// - Note: The best practice is to use strings for the table and column names in the migrations which wil make them work also in case the entity they represent was modified or deleted.
public class Migrations {
  private var steps: [(String, () async throws -> Void)] = []
  
  /// Add a migrations step
  /// - Parameters:
  ///   - name: name os step
  ///   - block: block to execute for this step
  public func add(_ name: String, block: @escaping () async throws -> Void) {
    steps.append((name, block))
  }
  
  /// Perfrom all the migration steps that weren't executed yet.
  public func perform() async throws {
    try await Database.handler.execute("""
    CREATE TABLE IF NOT EXISTS _Migrations (
      id varchar(80) UNIQUE NOT NULL PRIMARY KEY
    );
    """)
    
    // find more recent migration that wasn't performed
    let all: Set<String> = try await Set(PerformedMigration.select().execute().compactMap(\.id))
    if let idx = steps.firstIndex(where: { !all.contains($0.0) }) {
      for step in steps[idx...] {
        try await step.1()
        let mig = PerformedMigration()
        mig.id = step.0
        try await mig.insert()
      }
    }
  }
  
  public init() {}
}

@TableObject(columns: .camelCase, table: "_Migrations", idType: String.self, trackDirty: false)
internal struct PerformedMigration: Hashable {
  static func == (lhs: PerformedMigration, rhs: PerformedMigration) -> Bool {
    lhs.id == rhs.id
  }
    
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    _ = Self.column(.id)
  }
  
  init() {}
}

/// Postgres Column type
public enum ColumnType: String {
  /// Swift Int
  case int = "int4"
  /// Swift It64
  case int64 = "int8"
  /// Siwft Int16
  case int16 = "int2"
  /// Swift Float
  case float = "float4"
  /// Swift Double
  case double = "float8"
  /// Swift Bool
  case bool
  /// Swift String
  case string = "text"
  /// Codable type encoded as json
  case codable = "jsonb"
  /// Date
  case date
  /// UUID
  case uuid
  /// Auto incremented int
  case serial
  /// Auto incremented int64
  case int64serial = "bigserial"
  /// auto incremented int16
  case int16serial = "smallserial"
  @_documentation(visibility: private)
  case unknwon = ""
  
  /// Swift Int32, equeals Swift Int
  public static var int32 = ColumnType.int
  /// int32 auto increamnted
  public static var int32serial = ColumnType.serial
}

@_documentation(visibility: private)
public struct ColumnDefinitation {
  var name: String
  var type: ColumnType
  
  enum Operation {
    case drop
    case rename(String)
    case add
    case alter
    
    var isAdd: Bool {
      switch self {
      case .add: return true
      default: return false
      }
    }
  }

  var operation: Operation = .add
  enum Constraints {
    case unique
    case notNull
    case primaryKey
    case foreignKey(table: String, column: String, onDelete: DeleteAction)
    case defaultValue(String)
  }

  public enum DeleteAction: String {
    case cascade = "CASCADE"
    case setNull = "SET NULL"
    case setDefault = "SET DEFAULT"
    case restrict = "RESTRICT"
    case noAction = "NO ACTION"
  }

  var constraints: [Constraints] = []
  
  public func drop() throws -> Self {
    guard operation.isAdd else {
      throw TableObjectError.general("column operation for \(name) already specified")
    }
    return ColumnDefinitation(name: name, type: type, operation: .drop, constraints: constraints)
  }
  
  public func rename(_ newName: ColumnName) throws -> Self {
    guard operation.isAdd else {
      throw TableObjectError.general("column operation for \(name) already specified")
    }
    return ColumnDefinitation(name: name, type: type, operation: .rename(newName.name), constraints: constraints)
  }
  
  public func update(_ type: ColumnType) throws -> Self {
    guard operation.isAdd else {
      throw TableObjectError.general("column operation for \(name) already specified")
    }
    return ColumnDefinitation(name: name, type: type, operation: .alter, constraints: constraints)
  }
  
  public func unique() -> Self {
    ColumnDefinitation(name: name, type: type, operation: operation, constraints: constraints + [.unique])
  }
  
  public func notNull() -> Self {
    ColumnDefinitation(name: name, type: type, operation: operation, constraints: constraints + [.notNull])
  }
  
  public func primatyKey() -> Self {
    ColumnDefinitation(name: name, type: type, operation: operation, constraints: constraints + [.primaryKey])
  }
  
  public func references(table: String, column: String, onDelete: DeleteAction = .noAction) -> Self {
    ColumnDefinitation(name: name, type: type, operation: operation, constraints: constraints + [.foreignKey(table: table, column: column, onDelete: onDelete)])
  }
  
  public func defaultValue(_ value: String) -> Self {
    ColumnDefinitation(name: name, type: type, operation: operation, constraints: constraints + [.defaultValue(value)])
  }
  
  var columnConstraints: String {
    constraints.compactMap {
      switch $0 {
      case .unique:
        return "UNIQUE"
      case .notNull:
        return "NOT NULL"
      case .primaryKey:
        return "PRIMARY KEY"
      case let .defaultValue(value):
        return "DEFAULT \(value)"
      default:
        return nil
      }
    }
    .joined(separator: " ")
  }
  
  var tableConstraints: String {
    constraints.compactMap {
      switch $0 {
      case let .foreignKey(table: table, column: tableColumn, onDelete: action):
        return "FOREIGN KEY (\(name)) REFERENCES \(table)(\(tableColumn)) ON DELETE \(action.rawValue)"
      default:
        return nil
      }
    }
    .joined(separator: ";\n")
  }
}

@_documentation(visibility: private)
public struct TableDefinition {
  let name: String
  public enum Operation {
    case create
    case alter
    case drop
  }

  var columns: [ColumnDefinitation] = []
  
  func sql(operation: Operation) throws -> String {
    switch operation {
    case .create:
      var elements = [String]()
      try columns.forEach {
        guard $0.operation.isAdd else {
          throw TableObjectError.general("can only add columns when creating a table: table \(name), column \($0.name)")
        }
        elements.append("\($0.name) \($0.type.rawValue) \($0.columnConstraints)")
      }
      columns.forEach {
        let tableConstraint = $0.tableConstraints
        if !tableConstraint.isEmpty {
          elements.append(tableConstraint)
        }
      }
      return "CREATE TABLE \(name) (\n\(elements.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: ",\n"))\n);"
      
    case .drop:
      return "DROP TABLE \(name);"
      
    case .alter:
      var elements = [String]()
      try columns.forEach {
        let statement: String
        switch $0.operation {
        case .drop:
          statement = "ALTER TABLE \(name) DROP COLUMN \($0.name);"
        case let .rename(newName):
          guard $0.constraints.isEmpty else {
            throw TableObjectError.general("Constraint modification not supported, use literal SQL")
          }
          statement = "ALTER TABLE \(name) RENAME COLUMN \(name) TO \(newName);"
        case .add:
          var comp = ["ALTER TABLE \(name) ADD \($0.name) \($0.type.rawValue)\($0.columnConstraints.isEmpty ? "" : " \($0.columnConstraints)");"]
          if !$0.tableConstraints.isEmpty {
            comp.append("ALTER TABLE \(name) ADD \($0.tableConstraints);")
          }
          statement = comp.joined(separator: "\n")
        case .alter:
          guard $0.constraints.isEmpty else {
            throw TableObjectError.general("Constraint modification not supported, use literal SQL")
          }
          statement = "ALTER TABLE \(name) ALTER COLUMN \($0.name) TYPE \($0.type.rawValue);"
        }
        elements.append(statement)
      }
      return elements.joined(separator: "\n")
    }
  }
  
  public func create() async throws {
    try await Database.handler.execute(sql(operation: .create))
  }
  
  public func update() async throws {
    try await Database.handler.execute(sql(operation: .alter))
  }
  
  public func drop() async throws {
    try await Database.handler.execute(sql(operation: .drop))
  }
}

@_documentation(visibility: private)
public func column(_ name: String, type: ColumnType = .unknwon) -> ColumnDefinitation {
  ColumnDefinitation(name: name, type: type)
}

@_documentation(visibility: private)
public func table(_ name: String, @ArrayBuilder<ColumnDefinitation> columns: () throws -> [ColumnDefinitation] = { [] }) rethrows -> TableDefinition {
  try TableDefinition(name: name, columns: columns())
}
