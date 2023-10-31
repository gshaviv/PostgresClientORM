//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresClientKit

public protocol TableObject: Codable, FieldGroup {
  static var tableName: String { get }
  associatedtype IDType: PostgresValueConvertible
  var id: Self.IDType? { get nonmutating set }
  var dbHash: Int? { get nonmutating set }
  static var idColumn: ColumnName { get }
  static func column(_ key: Key) -> ColumnName
}

public extension TableObject {
  static func select() -> SQLQuery<Self> {
    SQLQuery(base: "SELECT * FROM \(tableName)")
  }

  static func delete() -> SQLQuery<Self> {
    SQLQuery(base: "DELETE FROM \(tableName)")
  }

  func delete() -> SQLQuery<Self> {
    Self.delete().where {
      Self.idColumn == id
    }
  }

  static func count() -> SQLQuery<CountRetrieval> {
    SQLQuery(base: "SELECT count(*) FROM \(tableName)")
  }

  var dbHash: Int? {
    get { -1 }
    nonmutating set {}
  }

  static func fetch(id: IDType, transaction: UUID? = nil) async throws -> Self? {
    try await select().where {
      idColumn == id
    }
    .transaction(transaction)
    .execute().first
  }

  func insert(transation: UUID? = nil) async throws {
    if let optionalid = id as? UUID?, optionalid == nil {
      id = UUID() as? IDType
    }
    let insertQuery = try SQLEncoder().encode(self, as: .insert)
    _ = try await insertQuery.transaction(transation).execute()
    dbHash = try calculcateDbHash()
  }

  func update(transaction: UUID? = nil) async throws {
    guard id != nil else {
      throw PostgresError.valueIsNil
    }
    let updateQuery = try SQLEncoder().encode(self, as: .partialUpdate).where {
      Self.idColumn == id
    }
    _ = try await updateQuery.transaction(transaction).execute()
    dbHash = try calculcateDbHash()
  }

  func isDirty() throws -> Bool {
    guard dbHash != -1 else {
      throw TableObjectError.unsupported
    }
    return try dbHash != calculcateDbHash()
  }

  func save(transaction: UUID? = nil) async throws {
    guard dbHash != -1 else {
      throw TableObjectError.unsupported
    }
    if id == nil || dbHash == nil {
      try await insert(transation: transaction)
    } else {
      guard try isDirty() else {
        return
      }
      try await update(transaction: transaction)
    }
  }

  func calculcateDbHash() throws -> Int {
    let hashable = try SQLEncoder().encode(self, as: .partialUpdate)
    return hashable.sqlString.hashValue
  }
}

public enum TableObjectError: Error {
  case general(String)
  case unsupported
}
