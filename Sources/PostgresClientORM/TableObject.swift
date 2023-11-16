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

  func delete(transaction: UUID? = nil) async throws {
    _ = try await Query<Self>(sql: "DELETE FROM \(Self.tableName)")
      .where {
        Self.idColumn == id
      }
      .execute(transaction: transaction)
  }

  static func delete() -> Query<Self> {
    Query(sql: "DELETE FROM \(tableName)")
  }

  static func count() -> Query<CountRetrieval> {
    Query(sql: "SELECT count(*) FROM \(tableName)")
  }

  static func fetch(id: IDType?, transaction: UUID? = nil) async throws -> Self? {
    guard let id else {
      return nil
    }
    return try await select().where {
      idColumn == id
    }
    .execute(transaction: transaction).first
  }

  nonmutating func insert(transaction: UUID? = nil) async throws {
    if let optionalid = id as? UUID?, optionalid == nil {
      id = UUID() as? IDType
    }
    let insertQuery = try RowWriter().encode(self, as: .insert)
    _ = try await insertQuery.execute(transaction: transaction)
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  nonmutating func update(transaction: UUID? = nil) async throws {
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
    _ = try await updateQuery.execute(transaction: transaction)
    if let saveableSelf = self as? any SaveableTableObject {
      saveableSelf.dbHash = try saveableSelf.calculcateDbHash()
    }
  }

  nonmutating func updateColumns(_ columns: ColumnName..., transaction: UUID? = nil) async throws {
    guard id != nil else {
      throw PostgresError.protocol("id is nil")
    }
    let updateQuery = try RowWriter().encode(self, as: .updateColumns(columns)).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.execute(transaction: transaction)
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

public protocol TrackingDirty {
  var dbHash: Int? { get nonmutating set }
}

public extension TrackingDirty where Self: TableObject {
  nonmutating func save(transaction: UUID? = nil) async throws {
    if id == nil || dbHash == nil {
      try await insert(transaction: transaction)
    } else {
      try await update(transaction: transaction)
    }
  }

  nonmutating func isDirty() throws -> Bool {
    try dbHash != calculcateDbHash()
  }
}

public typealias SaveableTableObject = TableObject & TrackingDirty
