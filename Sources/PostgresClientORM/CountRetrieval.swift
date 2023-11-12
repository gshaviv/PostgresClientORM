//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresClientKit

public struct CountRetrieval: TableObject {
  public static var idColumn: ColumnName { column(.count) }
  public typealias Columns = CodingKeys

  public enum CodingKeys: String, CodingKey {
    case count
  }

  let _idHolder = OptionalContainer<Int>()
  @DBHash public var dbHash: Int?
  public var id: Int? {
    get { _idHolder.value }
    nonmutating set { _idHolder.value = newValue }
  }
  var count: Int
  public static let tableName = ""
  
  public init(row: RowReader) throws {
    let container = try row.container(keyedBy: CodingKeys.self)
    self.count = try container.decode(Int.self, forKey: .count)
  }
  
  public func encode(row: RowWriter) throws {
    var container = row.container(keyedBy: CodingKeys.self)
    try container.encode(self.count, forKey: .count)
  }
}

public extension SQLQuery<CountRetrieval> {
  func execute(transaction: UUID? = nil) async throws -> Int {
    try await Database.handler.getCount(sqlQuery: self, transaction: transaction)
  }
}
