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

  init(query: Query<Type>) {
    self.query = query
  }

  public func makeAsyncIterator() -> QueryResultIterator<Type> {
    QueryResultIterator(query: query.postgresQuery)
  }
}

@_documentation(visibility: private)
public struct QueryResultIterator<T: FieldSubset>: AsyncIteratorProtocol {
  private var query: PostgresQuery
  private var connection: PostgresConnection?
  private var result: PostgresRowSequence?
  private var iterator: PostgresRowSequence.AsyncIterator?

  init(query: PostgresQuery) {
    self.query = query
  }

  public mutating func next() async throws -> T? {
    if iterator == nil {
      let connection = try await ConnectionGroup.shared.obtain()
      self.connection = connection
      let result = try await connection.query(query, logger: connection.logger)
      self.result = result
      iterator = result.makeAsyncIterator()
    }
    guard let row = try await iterator?.next() else {
      if let connection {
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
