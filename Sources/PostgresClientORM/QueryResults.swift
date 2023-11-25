//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresNIO

@_documentation(visibility: private)
public struct QueryResults<Type: FieldSubset>: AsyncSequence {
  public typealias AsyncIterator = QueryResultIterator<Type>
  public typealias Element = Type
  private var query: Query<Type>
  private var connection: PostgresConnection?

  init(query: Query<Type>, connection: PostgresConnection? = nil) {
    self.query = query
    self.connection = connection
  }

  public func makeAsyncIterator() -> QueryResultIterator<Type> {
    QueryResultIterator(query: query.postgresQuery, connection: connection)
  }
}

@_documentation(visibility: private)
public struct QueryResultIterator<T: FieldSubset>: AsyncIteratorProtocol {
  private var query: PostgresQuery
  private var connection: PostgresConnection?
  private var result: PostgresRowSequence?
  private var iterator: PostgresRowSequence.AsyncIterator?
  private var releaseConnectin: Bool

  init(query: PostgresQuery, connection: PostgresConnection?) {
    self.query = query
    self.connection = connection
    releaseConnectin = connection == nil
  }

  public mutating func next() async throws -> T? {
    if iterator == nil {
      let resultConnection: PostgresConnection
      if let connection {
        resultConnection = connection
      } else {
        resultConnection = try await ConnectionGroup.shared.obtain()
        self.connection = resultConnection
      }
      let result = try await resultConnection.query(query, logger: resultConnection.logger)
      self.result = result
      iterator = result.makeAsyncIterator()
    }
    
    guard let row = try await iterator?.next() else {
      if let connection, releaseConnectin {
        ConnectionGroup.shared.release(connection: connection)
      }
      return nil
    }
    let v = try RowReader(row: row).decode(T.self)
    if let v = v as? any SaveableTableObject {
      v.dbHash = try v.calculcateDbHash()
    }
    return v
  }
}
