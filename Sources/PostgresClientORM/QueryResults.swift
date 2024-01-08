//
//  QueryResults.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PerfectPostgreSQL

@_documentation(visibility: private)
public struct QueryResults<Type: FieldSubset>: AsyncSequence {
  public typealias AsyncIterator = QueryResultIterator<Type>
  public typealias Element = Type
  private var query: Query<Type>
  private var connection: DatabaseConnection?

  init(query: Query<Type>, connection: DatabaseConnection? = nil) {
    self.query = query
    self.connection = connection
  }

  public func makeAsyncIterator() -> QueryResultIterator<Type> {
    QueryResultIterator(query: query, connection: connection)
  }
}

@_documentation(visibility: private)
public class QueryResultIterator<T: FieldSubset>: AsyncIteratorProtocol {
  private var query: Query<T>
  private var connection: DatabaseConnection?
  private var result: PGResult?
  private var iterator: Range<Int>.Iterator?
  private var releaseConnection: Bool
  private var resultRow: ResultRow?

  init(query: Query<T>, connection: DatabaseConnection?) {
    self.query = query
    self.connection = connection
    releaseConnection = connection == nil
  }

  deinit {
    result?.clear()
  }

  public func next() async throws -> T? {
    if iterator == nil {
      let resultConnection: DatabaseConnection
      if let connection {
        resultConnection = connection
      } else {
        resultConnection = try DatabaseConnector.connect()
        connection = resultConnection
      }
      let result = try resultConnection.execute(statement: query.sqlString, params: query.bindings)
      self.result = result
      iterator = (0 ..< result.numTuples()).makeIterator()
    }

    guard let row = iterator?.next(), let result else {
      return nil
    }
    var rowResult = resultRow ?? ResultRow(result: result, row: row)
    rowResult.row = row
    resultRow = rowResult
    let v = try RowReader(row: rowResult).decode(T.self)
    if let v = v as? any SaveableTableObject {
      v.dbHash = try v.calculcateDbHash()
    }
    return v
  }
}
