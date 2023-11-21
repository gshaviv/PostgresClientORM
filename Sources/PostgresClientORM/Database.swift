//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresNIO

public actor Database {
  public static let handler = Database()
  private var activeTransaction: (task: Task<Void, Error>, id: UUID)?

  private init() {}

  func getCount(sqlQuery: Query<CountRetrieval>, transaction: UUID? = nil) async throws -> Int {
    if let activeTransaction, activeTransaction.id != transaction {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    let rows = try await connection.query(sqlQuery.postgresQuery, logger: connection.logger)
    for try await count in rows.decode(Int.self) {
      return count
    }
    throw TableObjectError.general("no count")
  }

  public func execute<TYPE: FieldSubset>(sqlQuery: Query<TYPE>, transaction: UUID? = nil) async throws -> [TYPE] {
    if let activeTransaction, activeTransaction.id != transaction {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    do {
      var items = [TYPE]()
      let results = sqlQuery.results
      for try await item in results {
        items.append(item)
      }
      ConnectionGroup.shared.release(connection: connection)

      return items
    } catch {
      ConnectionGroup.shared.release(connection: connection)
      throw error
    }
  }

  public func execute<RET: PostgresDecodable>(sqlQuery: Query<some FieldSubset>, returning: RET.Type, transaction: UUID? = nil) async throws -> RET {
    if let activeTransaction, activeTransaction.id != transaction {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    do {
      let rows = try await connection.query(sqlQuery.postgresQuery, logger: connection.logger)
      var iterator = rows.makeAsyncIterator()
      guard let row = try await iterator.next() else {
        throw TableObjectError.general("No return value")
      }
      return try row.decode(RET.self)
    } catch {
      ConnectionGroup.shared.release(connection: connection)
      throw error
    }
  }

  public func execute<TYPE: FieldSubset>(decode: TYPE.Type, _ sqlText: String, transaction id: UUID? = nil) async throws -> [TYPE] {
    if let activeTransaction, activeTransaction.id != id {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()

    do {
      let rows = try await connection.query(PostgresQuery(stringLiteral: sqlText), logger: connection.logger)
      var iterator = rows.makeAsyncIterator()

      var items = [TYPE]()

      while let row = try await iterator.next() {
        let decoder = RowReader(row: row)
        let v = try decoder.decode(TYPE.self)

        if let v = v as? any SaveableTableObject {
          v.dbHash = try v.calculcateDbHash()
        }
        items.append(v)
      }

      ConnectionGroup.shared.release(connection: connection)
      return items
    } catch {
      ConnectionGroup.shared.release(connection: connection)
      throw error
    }
  }

  public func execute(_ sqlText: String, transaction id: UUID? = nil) async throws {
    if let activeTransaction, activeTransaction.id != id {
      try await activeTransaction.task.value
    }
    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    try await connection.query(PostgresQuery(stringLiteral: sqlText), logger: connection.logger)
  }

  public func transaction(_ transactionBlock: @escaping (_ transactionId: UUID) async throws -> Void) async throws {
    if let activeTransaction {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    do {
      let tid = UUID()
      activeTransaction = (task: Task<Void, Error> {
        try await connection.beginTransaction()
        do {
          try await transactionBlock(tid)
          try await connection.commitTransaction()
        } catch {
          try await connection.rollbackTransaction()
        }
        self.activeTransaction = nil
      }, id: tid)

      try await activeTransaction?.task.value
      ConnectionGroup.shared.release(connection: connection)
    } catch {
      ConnectionGroup.shared.release(connection: connection)
      throw error
    }
  }
}

public extension PostgresConnection {
  func beginTransaction() async throws {
    try await query("begin transaction", logger: logger)
  }

  func commitTransaction() async throws {
    try await query("commit", logger: logger)
  }

  func rollbackTransaction() async throws {
    try await query("rollback", logger: logger)
  }
}
