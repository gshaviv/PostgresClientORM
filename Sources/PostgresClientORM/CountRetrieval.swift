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
  public typealias Key = CodingKeys

  public enum CodingKeys: String, CodingKey {
    case count
  }

  @ID public var id: Int?
  var count: Int
  public static let tableName = ""
}

extension SQLQuery<CountRetrieval> {
  func execute() async throws -> Int {
    try await DatabaseActor.shared.getCount(sqlQuery: self)
  }
}
