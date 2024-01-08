//
//  TableObject.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PerfectPostgreSQL

public protocol TableObject: FieldSubset {
  static var tableName: String { get }
  associatedtype IDType: Codable & LosslessStringConvertible
  var id: Self.IDType? { get nonmutating set }
  static var idColumn: ColumnName { get }
}

public extension TableObject {
  static func select() -> Query<Self> {
    Query(sql: "SELECT * FROM \(tableName)")
  }

  func delete(connection: DatabaseConnection? = nil) async throws {
    _ = try await Query<Self>(sql: "DELETE FROM \(Self.tableName)")
      .where {
        Self.idColumn == id
      }
      .execute(connection: connection)
  }

  static func delete() -> Query<Self> {
    Query(sql: "DELETE FROM \(tableName)")
  }

  static func count() -> Query<CountRetrieval> {
    Query(sql: "SELECT count(*) FROM \(tableName)")
  }

  static func fetch(id: IDType?, connection: DatabaseConnection? = nil) async throws -> Self? {
    guard let id else {
      return nil
    }
    return try await select().where {
      idColumn == id
    }
    .execute(connection: connection).first
  }

  nonmutating func insert(connection: DatabaseConnection? = nil) async throws {
    if let optionalid = id as? UUID?, optionalid == nil {
      id = UUID() as? IDType
    }
    let insertQuery = try RowWriter().encode(self, as: .insert)
    if id is (any AutoIncrementable)? {
      id = try await Database.handler.execute(sqlQuery: insertQuery.returning(Self.idColumn), returning: IDType.self, connection: connection)
    } else {
      _ = try await insertQuery.execute(connection: connection)
    }
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  nonmutating func update(connection: DatabaseConnection? = nil) async throws {
    guard id != nil else {
      throw TableObjectError.general("id is nil")
    }
    if let self = self as? any SaveableTableObject {
      guard try self.isDirty() else {
        return
      }
    }
    let updateQuery = try RowWriter().encode(self, as: .update).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.execute(connection: connection)
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  nonmutating func updateColumns(_ columns: ColumnName..., connection: DatabaseConnection? = nil) async throws {
    guard id != nil else {
      throw TableObjectError.general("id is nil")
    }
    let updateQuery = try RowWriter().encode(self, as: .updateColumns(columns)).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.execute(connection: connection)
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  func calculcateDbHash() throws -> Int {
    let hashable = try RowWriter().encode(self, as: .update)
    var hasher = Hasher()
    hashable.bindings.forEach {
      if let v = $0 as? any Hashable {
        hasher.combine(v)
      }
    }
    return hasher.finalize()
  }
}

public enum TableObjectError: Error, LocalizedError {
  case general(String)
  case unsupported

  public var errorDescription: String? {
    switch self {
    case let .general(message):
      "TableObject Error: \(message)"
    case .unsupported:
      "TableObject Unsupported"
    }
  }
}

/// A type that can track it's dirty status
///
/// Types automatically conform to this protocol if track their direty said, i.e. if they were modified after being loaded from the database.
public protocol TrackingDirty {
  @_documentation(visibility: private)
  var dbHash: Int? { get nonmutating set }
}

public extension TrackingDirty where Self: TableObject {
  /// Save the receiver
  /// - Parameter connection: optional: transaction connection
  ///
  /// If the receiver is not dirty this method does nothing. If it is dirty it wil update the database record for the instance. If this is a new object that was never read from the database, this method will insert it.
  nonmutating func save(connection: DatabaseConnection? = nil) async throws {
    if id == nil || dbHash == nil {
      try await insert(connection: connection)
    } else {
      try await update(connection: connection)
    }
  }

  /// Is instance dirty?
  ///
  /// An instance is dirty if it was modified in memroy after being read from the database.
  /// - Note: The framework does not check if the object was modifed in the database after being read, only if it was modified in process.
  ///
  /// - Returns: Bool indicating dirty status
  nonmutating func isDirty() throws -> Bool {
    try dbHash != calculcateDbHash()
  }
}

public typealias SaveableTableObject = TableObject & TrackingDirty

private protocol AutoIncrementable {}
extension Int: AutoIncrementable {}
extension Int16: AutoIncrementable {}
extension Int32: AutoIncrementable {}
extension Int64: AutoIncrementable {}

extension UUID: LosslessStringConvertible {
  public init?(_ description: String) {
    self.init(uuidString: description)
  }
}
