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

  let _idHolder = IDHolder<Int>()
  public var id: Int? {
    get { _idHolder.value }
    nonmutating set { _idHolder.value = newValue }
  }
  var count: Int
  public static let tableName = ""
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.count = try container.decode(Int.self, forKey: .count)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.count, forKey: .count)
  }
}

extension SQLQuery<CountRetrieval> {
  func execute() async throws -> Int {
    try await DatabaseActor.shared.getCount(sqlQuery: self)
  }
}
