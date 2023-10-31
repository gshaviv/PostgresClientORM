//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation

public protocol FieldGroup: Codable {
  associatedtype Key: CodingKey
  static func column(_ key: Key) -> ColumnName
}

public extension FieldGroup {
  static func column(_ key: Key) -> ColumnName {
    ColumnName(key.stringValue)
  }
}
