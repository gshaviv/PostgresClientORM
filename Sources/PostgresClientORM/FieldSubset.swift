//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation

public protocol FieldSubset {
  associatedtype Columns: CodingKey
  init(row: RowReader) throws
  func encode(row: RowWriter) throws
}

public extension FieldSubset {
  static func column(_ key: Columns) -> ColumnName {
    ColumnName(key.stringValue)
  }
}

extension Optional: FieldSubset where Wrapped: FieldSubset {
  public init(row: RowReader) throws {
    do {
      self = try .some(Wrapped(row: row))
    } catch {
      self = .none
    }
  }

  public func encode(row: RowWriter) throws {
    switch self {
    case .none:
      break
    case .some(let wrapped):
      try wrapped.encode(row: row)
    }
  }

  public typealias Columns = Wrapped.Columns
}
