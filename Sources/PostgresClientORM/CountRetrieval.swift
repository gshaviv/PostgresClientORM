//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresNIO

public struct CountRetrieval: TableObject {
  public static var idColumn: ColumnName { column(.count) }
  public typealias Columns = CodingKeys

  public enum CodingKeys: String, CodingKey {
    case count
  }

  let _idHolder = OptionalContainer<Int>()
  public var id: Int? {
    get { _idHolder.value }
    nonmutating set { _idHolder.value = newValue }
  }
  var count: Int
  public static let tableName = ""
  
  public init(row: RowReader) throws {
    let decode = row.decoder(keyedBy: CodingKeys.self)
    self.count = try decode(Int.self, forKey: .count)
  }
  
  public func encode(row: RowWriter) throws {
    let encode = row.encoder(keyedBy: CodingKeys.self)
    try encode(self.count, forKey: .count)
  }
}

public extension Query<CountRetrieval> {
  func execute(transaction: UUID? = nil) async throws -> Int {
    try await Database.handler.getCount(sqlQuery: self, transaction: transaction)
  }
}
