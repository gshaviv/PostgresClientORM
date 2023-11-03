//
//  File.swift
//
//
//  Created by Guy Shaviv on 28/10/2023.
//

import Foundation
import PostgresClientKit

public typealias StepBlock = (UUID) async throws -> Void

public class Migrations {
  private var steps: [(String, StepBlock)] = []
  
  public func addMigration(_ name: String, block: @escaping StepBlock) {
    steps.append((name, block))
  }
  
  public func perform() async throws {
    try await DatabaseActor.shared.execute("""
    CREATE TABLE IF NOT EXISTS _Migrations (
      id varchar(80) UNIQUE NOT NULL PRIMARY KEY
    );
    """)
    
    // find more recent migration that wasn't performed
    let all: Set<String> = try await Set(PerformedMigration.select().execute().compactMap(\.id))
    if let idx = steps.firstIndex(where: { !all.contains($0.0) }) {
      for step in steps[idx...] {
        try await DatabaseActor.shared.transaction { transactionId in
          try await step.1(transactionId)
          let mig = PerformedMigration()
          mig.id = step.0
          try await mig.insert(transation: transactionId)
        }
      }
    }
  }
  
  public init() {}
}

@TablePersist(.camelCase, trackDirty: false)
struct PerformedMigration: Hashable {
  static var tableName = "_Migrations"
  static func == (lhs: PerformedMigration, rhs: PerformedMigration) -> Bool {
    lhs.id == rhs.id
  }
  
  @ID var id: String?
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  init() {}
}

public enum ColumnType: String {
  case int = "int4"
  case int64 = "int8"
  case int16 = "int2"
  case int8 = "int1"
  case float = "float4"
  case double = "float8"
  case bool
  case string = "text"
  case codable = "jsonb"
  case date
  case uuid
  case unknwon = ""
  
  public static var int32 = ColumnType.int
}

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
    case defaultValue(PostgresValueConvertible)
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
  
  public func rename(_ newName: String) throws -> Self {
    guard operation.isAdd else {
      throw TableObjectError.general("column operation for \(name) already specified")
    }
    return ColumnDefinitation(name: name, type: type, operation: .rename(newName), constraints: constraints)
  }
  
  public func alter(_ type: ColumnType) throws -> Self {
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
  
  public func defaultValue(_ value: PostgresValueConvertible) -> Self {
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
        return "DEFAULT \(value.sqlString)"
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

public struct TableDefinition {
  let name: String
  public enum Operation {
    case create
    case alter
    case drop
  }

  var operation: Operation
  var columns: [ColumnDefinitation] = []
  
  func sql() throws -> String {
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
}

public func column(_ name: String, type: ColumnType = .unknwon) -> ColumnDefinitation {
  ColumnDefinitation(name: name, type: type)
}

public func table(_ name: String, _ op: TableDefinition.Operation = .create, @ArrayBuilder<ColumnDefinitation> columns: () throws -> [ColumnDefinitation] = { [] }) rethrows -> TableDefinition {
  try TableDefinition(name: name, operation: op, columns: columns())
}
