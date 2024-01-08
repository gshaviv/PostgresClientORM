//
//  CountRetrieval.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PerfectPostgreSQL

@_documentation(visibility: private)
public struct CountRetrieval: TableObject {
  public static var idColumn: ColumnName { column(.count) }

  public enum Columns: String, CodingKey {
    case count
  }

  let _idHolder = OptionalContainer<Int>()
  public var id: Int? {
    get { _idHolder.value }
    nonmutating set { _idHolder.value = newValue }
  }

  var count: Int
  public static let tableName = ""

  public init(row: RowDecoder<Columns>) throws {
    count = try row.decode(Int.self, forKey: .count)
  }

  public func encode(row: RowEncoder<Columns>) throws {
    try row.encode(count, forKey: .count)
  }
}

public extension Query<CountRetrieval> {
  func execute(connection: DatabaseConnection? = nil) async throws -> Int {
    try await Database.handler.getCount(sqlQuery: self, connection: connection)
  }
}
