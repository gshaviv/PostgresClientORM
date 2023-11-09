//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresClientKit

public protocol TableObject: FieldSubset {
  static var tableName: String { get }
  associatedtype IDType: PostgresValueConvertible & Codable
  var id: Self.IDType? { get nonmutating set }
  static var idColumn: ColumnName { get }
}

public extension TableObject {
  static func select() -> SQLQuery<Self> {
    SQLQuery(base: "SELECT * FROM \(tableName)")
  }

  func delete(transaction: UUID? = nil) async throws {
    _ = try await SQLQuery(base: "DELETE FROM \(Self.tableName)")
      .transaction(transaction)
      .where {
        Self.idColumn == id
      }
      .execute()
  }

  static func count() -> SQLQuery<CountRetrieval> {
    SQLQuery(base: "SELECT count(*) FROM \(tableName)")
  }

  static func fetch(id: IDType?, transaction: UUID? = nil) async throws -> Self? {
    guard let id else {
      return nil
    }
    return try await select().where {
      idColumn == id
    }
    .transaction(transaction)
    .execute().first
  }

  nonmutating func insert(transation: UUID? = nil) async throws {
    if let optionalid = id as? UUID?, optionalid == nil {
      id = UUID() as? IDType
    }
    let insertQuery = try RowWriter().encode(self, as: .insert)
    _ = try await insertQuery.transaction(transation).execute()
    dbHash = try calculcateDbHash()
  }

  nonmutating func update(transaction: UUID? = nil) async throws {
    guard id != nil else {
      throw PostgresError.valueIsNil
    }
    if let self = self as? any SaveableTableObject {
      guard try self.isDirty() else {
        return
      }
    }
    let updateQuery = try RowWriter().encode(self, as: .partialUpdate).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.transaction(transaction).execute()
    dbHash = try calculcateDbHash()
  }

  nonmutating func updateColumns(_ columns: ColumnName..., transaction: UUID? = nil) async throws {
    guard id != nil else {
      throw PostgresError.valueIsNil
    }
    let updateQuery = try RowWriter().encode(self, as: .specificPartialUpdate(columns)).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.transaction(transaction).execute()
    dbHash = try calculcateDbHash()
  }

  var dbHash: Int? {
    get { nil }
    nonmutating set {}
  }

  func calculcateDbHash() throws -> Int {
    let hashable = try RowWriter().encode(self, as: .partialUpdate)
    return hashable.sqlString.hashValue
  }
}

public enum TableObjectError: Error {
  case general(String)
  case unsupported
}

public protocol TrackingDirty {
  var dbHash: Int? { get nonmutating set }
}

public extension TrackingDirty where Self: TableObject {
  nonmutating func save(transaction: UUID? = nil) async throws {
    if id == nil || dbHash == nil {
      try await insert(transation: transaction)
    } else {
      try await update(transaction: transaction)
    }
  }

  nonmutating func isDirty() throws -> Bool {
    try dbHash != calculcateDbHash()
  }
}

public typealias SaveableTableObject = TableObject & TrackingDirty
