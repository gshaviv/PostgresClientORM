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
  
  private init() {}
  
  func getCount(sqlQuery: Query<CountRetrieval>, transactionConnection: DatabaseConnection? = nil) async throws -> Int {
    let connection: DatabaseConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await Connection.obtain()
    }
    
    let rows = try await (transactionConnection ?? connection).query(sqlQuery.postgresQuery, logger: connection.logger)
    for try await count in rows.decode(Int.self) {
      return count
    }
    throw TableObjectError.general("no count")
  }
  
  /// Execute a ``Query``
  /// - Parameters:
  ///   - sqlQuery: the ``Query`` to execute
  ///   - transactionConnection: if part of transaction, the transaction connection (optional)
  /// - Returns: and array of results, TYPE is deried from the ``Query``
  public func execute<TYPE: FieldSubset>(sqlQuery: Query<TYPE>, transactionConnection: DatabaseConnection? = nil) async throws -> [TYPE] {
    let connection: DatabaseConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await Connection.obtain()
    }
    
    var items = [TYPE]()
    let results = sqlQuery.results(transactionConnection: connection)
    for try await item in results {
      items.append(item)
    }
    return items
  }
  
  /// Execute a ``Query`` with a RETURNING clause
  /// - Parameters:
  ///   - sqlQuery: the Query
  ///   - returning: The type being returned
  ///   - transaction: optional: if part of a transaction, it's id.
  /// - Returns: an instance of return type
  public func execute<RET: PostgresDecodable>(sqlQuery: Query<some FieldSubset>, returning: RET.Type, transactionConnection: DatabaseConnection? = nil) async throws -> RET {
    let connection: DatabaseConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await Connection.obtain()
    }
    
    let rows = try await connection.query(sqlQuery.postgresQuery, logger: connection.logger)
    var iterator = rows.makeAsyncIterator()
    guard let row = try await iterator.next() else {
      throw TableObjectError.general("No return value")
    }
    return try row.decode(RET.self)
  }
  
  /// Execute sql text, returning an array of results
  /// - Parameters:
  ///   - decode: The type of result to return
  ///   - sqlText: the text of the sql query to perform
  ///   - transactionConnection: (Optional)  if participating in a transaction)
  /// - Returns: an array of TYPE
  public func execute<TYPE: FieldSubset>(decode: TYPE.Type, _ sqlText: String, transactionConnection: DatabaseConnection? = nil) async throws -> [TYPE] {
    let connection: DatabaseConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await Connection.obtain()
    }
    
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
      
    return items
  }
  
  /// Execute an sql text with no return value
  /// - Parameters:
  ///   - sqlText: The SQL text to run
  ///   - transactionConnection: (optional) transaction connection
  public func execute(_ sqlText: String, transactionConnection: DatabaseConnection? = nil) async throws {
    let connection: DatabaseConnection = if let transactionConnection {
      transactionConnection
    } else {
      try await Connection.obtain()
    }
    
    try await connection.query(PostgresQuery(stringLiteral: sqlText), logger: connection.logger)
    try await connection.connection.close()
    print("done")
  }
  
  /// Perform database operations in a transaction
  /// - Parameter transactionBlock: The transaction block receives a transactionConnection parameter that has to be given to all database operations performed in the block.  The block either returns normally or throws an error in which case the transaction is rolled back
  /// - NOTE: **Important** remeber to include the transaction connection to the  database operations in the block, not doing so will cause the action to be performed outside the transaction.
  public func transaction(file: String = #file, line: Int = #line, _ transactionBlock: @escaping (_ connecction: DatabaseConnection) async throws -> Void) async throws {
    let connection = try await Connection.obtain()
    try await connection.beginTransaction()
    do {
      try await transactionBlock(connection)
      try await connection.commitTransaction()
    } catch {
      try await connection.rollbackTransaction()
    }
  }
}

public extension DatabaseConnection {
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
