//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation

public protocol FieldCodable {
  associatedtype Columns: CodingKey
  init(row: RowReader) throws
  func encode(row: RowWriter) throws
}

public extension FieldCodable {
  static func column(_ key: Columns) -> ColumnName {
    ColumnName(key.stringValue)
  }
}
