//
//  FieldSubset.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation

/// Protocol for encoding / decoding an SQL row
public protocol FieldSubset: Codable {
  /// The column keys
  /// A String based CodingKey enum with cases named after the properties that are encoded
  associatedtype Columns: CodingKey
  /// init an instance from a given SQL row result
  /// - Parameter row: A row decoder keyed by the type's ``Columns``
  init(row: RowDecoder<Columns>) throws
  /// encode the type to an SQL row
  /// - Parameter row: a row encoder keyed by the type's ``Columns``
  func encode(row: RowEncoder<Columns>) throws
}

public extension FieldSubset {
  /// Retrieve the column name for a given propety
  /// - Parameter key: The Column case (i.e. the property)
  /// - Returns: A ColumnName sruct
  ///
  /// - Note: A default implementation for this function is provided returning the Columns case string value
  static func column(_ key: Columns) -> ColumnName {
    ColumnName(key.stringValue)
  }
}

@_documentation(visibility: private)
extension Optional: FieldSubset where Wrapped: FieldSubset {
  public init(row: RowDecoder<Wrapped.Columns>) throws {
    do {
      self = try .some(Wrapped(row: row))
    } catch {
      self = .none
    }
  }

  public func encode(row: RowEncoder<Wrapped.Columns>) throws {
    switch self {
    case .none:
      break
    case let .some(wrapped):
      try wrapped.encode(row: row)
    }
  }

  public typealias Columns = Wrapped.Columns
}
