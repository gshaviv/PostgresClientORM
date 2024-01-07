//
//  Database.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PerfectPostgreSQL

/// The actor handling the database.
///
/// The database is configured via environement variables. **DATABASE_URL** if exsts is referred to first, otherwide the set of: **DATABASE_HOST**, **DATABASE_PORT** (defaut: 5432), **DATABASE_USER**, **DATABASE_PASSWORD**, **DATABASE_NAME** and **DATABASE_SSL** (default: true)
public actor Database {
  /// The shared Database handler instance
  public static let handler = Database()

  private init() {}

  func getCount(sqlQuery: Query<CountRetrieval>, transactionConnection: PGConnection? = nil) async throws -> Int {
    let connection: PGConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await ConnectionGroup.shared.obtain()
    }

    defer {
      if transactionConnection == nil {
        ConnectionGroup.shared.release(connection: connection)
      }
    }

    let rows = try connection.execute(statement: sqlQuery.sqlString, params: sqlQuery.bindings)
    defer {
      rows.clear()
    }
    if let count = rows.getFieldInt(tupleIndex: 0, fieldIndex: 0) {
      return count
    }
    throw TableObjectError.general("no count")
  }

  /// Execute a ``Query``
  /// - Parameters:
  ///   - sqlQuery: the ``Query`` to execute
  ///   - transactionConnection: if part of transaction, the transaction connection (optional)
  /// - Returns: and array of results, TYPE is deried from the ``Query``
  public func execute<TYPE: FieldSubset>(sqlQuery: Query<TYPE>, transactionConnection: PGConnection? = nil) async throws -> [TYPE] {
    let connection: PGConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await ConnectionGroup.shared.obtain()
    }

    do {
      var items = [TYPE]()
      let results = sqlQuery.results(transactionConnection: connection)
      for try await item in results {
        items.append(item)
      }
      if transactionConnection == nil {
        ConnectionGroup.shared.release(connection: connection)
      }
      return items
    } catch {
      if transactionConnection == nil {
        ConnectionGroup.shared.release(connection: connection)
      }
      throw error
    }
  }

  /// Execute a ``Query`` with a RETURNING clause
  /// - Parameters:
  ///   - sqlQuery: the Query
  ///   - returning: The type being returned
  ///   - transaction: optional: if part of a transaction, it's id.
  /// - Returns: an instance of return type
  public func execute<RET: LosslessStringConvertible>(sqlQuery: Query<some FieldSubset>, returning _: RET.Type, transactionConnection: PGConnection? = nil) async throws -> RET {
    let connection: PGConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await ConnectionGroup.shared.obtain()
    }
    defer {
      if transactionConnection == nil {
        ConnectionGroup.shared.release(connection: connection)
      }
    }

    let rows = try connection.execute(statement: sqlQuery.sqlString, params: sqlQuery.bindings)
    defer {
      rows.clear()
    }
    guard let str = rows.getFieldString(tupleIndex: 0, fieldIndex: 0), let ret = RET(str) else {
      throw TableObjectError.general("No return value")
    }
    return ret
  }

  /// Execute sql text, returning an array of results
  /// - Parameters:
  ///   - decode: The type of result to return
  ///   - sqlText: the text of the sql query to perform
  ///   - transactionConnection: (Optional)  if participating in a transaction)
  /// - Returns: an array of TYPE
  public func execute<TYPE: FieldSubset>(decode _: TYPE.Type, _ sqlText: String, transactionConnection: PGConnection? = nil) async throws -> [TYPE] {
    let connection: PGConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await ConnectionGroup.shared.obtain()
    }

    do {
      let rows = try connection.execute(statement: sqlText)
      defer {
        rows.clear()
      }
      var items = [TYPE]()

      for row in 0 ..< rows.numTuples() {
        let decoder = RowReader(row: ResultRow(result: rows, row: row))
        let v = try decoder.decode(TYPE.self)

        if let v = v as? any SaveableTableObject {
          v.dbHash = try v.calculcateDbHash()
        }
        items.append(v)
      }

      if transactionConnection == nil {
        ConnectionGroup.shared.release(connection: connection)
      }
      return items
    } catch {
      if transactionConnection == nil {
        ConnectionGroup.shared.release(connection: connection)
      }
      throw error
    }
  }

  /// Execute an sql text with no return value
  /// - Parameters:
  ///   - sqlText: The SQL text to run
  ///   - transactionConnection: (optional) transaction connection
  public func execute(_ sqlText: String, transactionConnection: PGConnection? = nil) async throws {
    let connection: PGConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await ConnectionGroup.shared.obtain()
    }

    defer {
      if transactionConnection == nil {
        ConnectionGroup.shared.release(connection: connection)
      }
    }

    let ret = try connection.execute(statement: sqlText)
    ret.clear()
  }

  /// Perform database operations in a transaction
  /// - Parameter transactionBlock: The transaction block receives a transactionConnection parameter that has to be given to all database operations performed in the block.  The block either returns normally or throws an error in which case the transaction is rolled back
  /// - NOTE: **Important** remeber to include the transaction connection to the  database operations in the block, not doing so will cause the action to be performed outside the transaction.
  public func transaction(file _: String = #file, line _: Int = #line, _ transactionBlock: @escaping (_ connecction: PGConnection) async throws -> Void) async throws {
    let connection = try await ConnectionGroup.shared.obtain()
    do {
      try connection.beginTransaction()
      do {
        try await transactionBlock(connection)
        try connection.commitTransaction()
      } catch {
        try connection.rollbackTransaction()
      }

      ConnectionGroup.shared.release(connection: connection)
    } catch {
      try connection.rollbackTransaction()
      ConnectionGroup.shared.release(connection: connection)
      throw error
    }
  }
}

public extension PGConnection {
  func beginTransaction() throws {
    try execute(statement: "begin transaction")
  }

  func commitTransaction() throws {
    try execute(statement: "commit")
  }

  func rollbackTransaction() throws {
    try execute(statement: "rollback")
  }
}
