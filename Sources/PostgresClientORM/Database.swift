//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresNIO

/// The actor handling the database.
///
/// The database is configured via environement variables. **DATABASE_URL** if exsts is referred to first, otherwide the set of: **DATABASE_HOST**, **DATABASE_PORT** (defaut: 5432), **DATABASE_USER**, **DATABASE_PASSWORD**, **DATABASE_NAME** and **DATABASE_SSL** (default: true)
public actor Database {
  /// The shared Database handler instance
  public static let handler = Database()
  private var activeTransaction: (task: Task<Void, Error>, id: UUID)?

  private init() {}

  func getCount(sqlQuery: Query<CountRetrieval>, transaction: UUID? = nil) async throws -> Int {
    if let activeTransaction, activeTransaction.id != transaction {
      PostgresClientORM.logger.info("SQL query \(sqlQuery.postgresQuery) waiting on transaction to finish")
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
  
  /// Execute a ``Query``
  /// - Parameters:
  ///   - sqlQuery: the ``Query`` to execute
  ///   - transaction: if part of transaction, the transaction id (optional)
  /// - Returns: and array of results, TYPE is deried from the ``Query``
  public func execute<TYPE: FieldSubset>(sqlQuery: Query<TYPE>, transaction: UUID? = nil) async throws -> [TYPE] {
    if let activeTransaction, activeTransaction.id != transaction {
      PostgresClientORM.logger.info("SQL query \(sqlQuery.postgresQuery) waiting on transaction to finish")
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
  
  /// Execute a ``Query`` with a RETURNING clause
  /// - Parameters:
  ///   - sqlQuery: the Query
  ///   - returning: The type being returned
  ///   - transaction: optional: if part of a transaction, it's id.
  /// - Returns: an instance of return type
  public func execute<RET: PostgresDecodable>(sqlQuery: Query<some FieldSubset>, returning: RET.Type, transaction: UUID? = nil) async throws -> RET {
    if let activeTransaction, activeTransaction.id != transaction {
      PostgresClientORM.logger.info("SQL query \(sqlQuery.postgresQuery) waiting on transaction to finish")
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
  
  /// Execute sql text, returning an array of results
  /// - Parameters:
  ///   - decode: The type of result to return
  ///   - sqlText: the text of the sql query to perform
  ///   - id: (Optional) transaction id if participating in a transaction)
  /// - Returns: an array of TYPE
  public func execute<TYPE: FieldSubset>(decode: TYPE.Type, _ sqlText: String, transaction id: UUID? = nil) async throws -> [TYPE] {
    if let activeTransaction, activeTransaction.id != id {
      PostgresClientORM.logger.info("SQL text \(sqlText) waiting on transaction to finish")
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
  
  /// Execute an sql text with no return value
  /// - Parameters:
  ///   - sqlText: The SQL text to run
  ///   - id: (optional) transaction id
  public func execute(_ sqlText: String, transaction id: UUID? = nil) async throws {
    if let activeTransaction, activeTransaction.id != id {
      PostgresClientORM.logger.info("SQL text \(sqlText) waiting on transaction to finish")
      try await activeTransaction.task.value
    }
    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    try await connection.query(PostgresQuery(stringLiteral: sqlText), logger: connection.logger)
  }
  
  /// Perform database operations in a transaction
  /// - Parameter transactionBlock: The transaction block receives a transaction id parameter that has to be given to all database operations performed in the block.  The block either returns normally or throws an error in which case the transaction is rolled back
  /// - NOTE: **Important** remeber to include the transaction ID in database operations in the block, not doing so will cause a dead lock.
  public func transaction(_ transactionBlock: @escaping (_ transactionId: UUID) async throws -> Void) async throws {
    if let activeTransaction {
      PostgresClientORM.logger.info("Waiting on previous transaction.")
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
      self.activeTransaction = nil
    } catch {
      try await connection.rollbackTransaction()
      ConnectionGroup.shared.release(connection: connection)
      self.activeTransaction = nil
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
