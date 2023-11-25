//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresNIO

public protocol TableObject: FieldSubset {
  static var tableName: String { get }
  associatedtype IDType: PostgresCodable & Codable
  var id: Self.IDType? { get nonmutating set }
  static var idColumn: ColumnName { get }
}

public extension TableObject {
  static func select() -> Query<Self> {
    Query(sql: "SELECT * FROM \(tableName)")
  }

  func delete(transactionConnection: PostgresConnection? = nil) async throws {
    _ = try await Query<Self>(sql: "DELETE FROM \(Self.tableName)")
      .where {
        Self.idColumn == id
      }
      .execute(transactionConnection: transactionConnection)
  }

  static func delete() -> Query<Self> {
    Query(sql: "DELETE FROM \(tableName)")
  }

  static func count() -> Query<CountRetrieval> {
    Query(sql: "SELECT count(*) FROM \(tableName)")
  }

  static func fetch(id: IDType?, transactionConnection: PostgresConnection? = nil) async throws -> Self? {
    guard let id else {
      return nil
    }
    return try await select().where {
      idColumn == id
    }
    .execute(transactionConnection: transactionConnection).first
  }

  nonmutating func insert(transactionConnection: PostgresConnection? = nil) async throws {
    if let optionalid = id as? UUID?, optionalid == nil {
      id = UUID() as? IDType
    }
    let insertQuery = try RowWriter().encode(self, as: .insert)
    _ = try await insertQuery.execute(transactionConnection: transactionConnection)
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  nonmutating func update(transactionConnection: PostgresConnection? = nil) async throws {
    guard id != nil else {
      throw PostgresError.protocol("id is nil")
    }
    if let self = self as? any SaveableTableObject {
      guard try self.isDirty() else {
        return
      }
    }
    let updateQuery = try RowWriter().encode(self, as: .update).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.execute(transactionConnection: transactionConnection)
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  nonmutating func updateColumns(_ columns: ColumnName..., transactionConnection: PostgresConnection? = nil) async throws {
    guard id != nil else {
      throw PostgresError.protocol("id is nil")
    }
    let updateQuery = try RowWriter().encode(self, as: .updateColumns(columns)).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.execute(transactionConnection: transactionConnection)
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  func calculcateDbHash() throws -> Int {
    let hashable = try RowWriter().encode(self, as: .update)
    return hashable.bindings.hashValue
  }
}

public enum TableObjectError: Error, LocalizedError {
  case general(String)
  case unsupported

  public var errorDescription: String? {
    switch self {
    case let .general(message):
      return "TableObject Error: \(message)"
    case .unsupported:
      return "TableObject Unsupported"
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
  /// - Parameter transaction: optional: transaction id
  ///
  /// If the receiver is not dirty this method does nothing. If it is dirty it wil update the database record for the instance. If this is a new object that was never read from the database, this method will insert it.
  nonmutating func save(transactionConnection: PostgresConnection? = nil) async throws {
    if id == nil || dbHash == nil {
      try await insert(transactionConnection: transactionConnection)
    } else {
      try await update(transactionConnection: transactionConnection)
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
