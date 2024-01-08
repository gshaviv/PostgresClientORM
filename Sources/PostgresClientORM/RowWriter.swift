//
//  RowWriter.swift
//
//
//  Created by Guy Shaviv on 26/10/2023.
//

import Foundation

class RowWriter {
  fileprivate var variableNames = [String]()
  fileprivate var values = [Any?]()
  private let prefix: [String]
  private weak var parentWriter: RowWriter?

  init(prefix: [String] = [], parent: RowWriter? = nil) {
    self.prefix = prefix
    parentWriter = parent
  }

  /// QueryType to encode
  public enum QueryType {
    /// An insert query
    case insert
    /// an SQL update query
    case update
    /// An update query containing only specific columns
    case updateColumns([ColumnName])
  }

  func encoder<Key>(keyedBy _: Key.Type) -> RowEncoder<Key> where Key: CodingKey {
    RowEncoder(prefix: prefix, writer: parentWriter ?? self)
  }

  /// Create a base query of type from instance
  /// - Parameters:
  ///   - value: the ``TableObject`` instance to encode
  ///   - queryType: type of query: .insert / .update or .updateColumns([ColumnList])
  /// - Returns: A Query for said instance of said type, need to add to it a where clause to define its scope.
  public func encode<T: TableObject>(_ value: T, as queryType: RowWriter.QueryType) throws -> Query<T> {
    try value.encode(row: encoder(keyedBy: T.Columns.self))
    switch queryType {
    case .insert:
      let sql = "INSERT INTO \(T.tableName) (\(variableNames.map { ColumnName(stringLiteral: $0).description }.joined(separator: ","))) VALUES (\((1 ... values.count).map { "$\($0)" }.joined(separator: ",")))"
      return try Query(sql: sql, variables: values)

    case .update:
      if let idIdx = variableNames.firstIndex(where: { $0 == T.idColumn.name }) {
        variableNames.remove(at: idIdx)
        values.remove(at: idIdx)
      }
      let sql = "UPDATE \(T.tableName) SET \(variableNames.map { ColumnName(stringLiteral: $0).description }.enumerated().map { "\($0.element) = $\($0.offset + 1)" }.joined(separator: ","))"
      return try Query(sql: sql, variables: values)
    case let .updateColumns(cols):
      for col in cols + [T.idColumn] {
        if let idIdx = variableNames.firstIndex(where: { $0 == col.name }) {
          variableNames.remove(at: idIdx)
          values.remove(at: idIdx)
        }
      }
      let sql = "UPDATE \(T.tableName) SET \(variableNames.map { ColumnName(stringLiteral: $0).description }.enumerated().map { "\($0.element) = $\($0.offset + 1)" }.joined(separator: ","))"
      return try Query(sql: sql, variables: values)
    }
  }
}

/// A row encoder keyed by a Columns type
public struct RowEncoder<Key: CodingKey> {
  private let prefix: [String]
  private let writer: RowWriter

  init(prefix: [String] = [], writer: RowWriter) {
    self.prefix = prefix
    self.writer = writer
  }

  private func variableName(forKey key: Key) -> String {
    (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
  }

  public func encode(_ value: Int, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: Int?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: Int8, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: Int8?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: Int16, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }

  public func encode(_ value: Int16?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }
  public func encode(_ value: Int32, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: Int32?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: Int64, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: Int64?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: UInt, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: UInt?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: UInt8, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: UInt8?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: UInt16, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: UInt16?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: UInt32, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: UInt32?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: UInt64, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: UInt64?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: String, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: String?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }
  
  public func encode(_ value: Bool, forKey key: Key) throws {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: Bool?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode(_ value: some Encodable, forKey key: Key) throws {
    if let value = value as? LosslessStringConvertible {
      writer.values.append(value.description)
      writer.variableNames.append(variableName(forKey: key))
    } else {
      guard let str = try String(data: JSONEncoder().encode(value), encoding: .utf8) else {
        throw TableObjectError.general("Failed to encode value for key: \(key.stringValue)")
      }
      writer.values.append(str)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode<T: RawRepresentable>(_ value: T, forKey key: Key) throws where T.RawValue == Int {
    try encode(value.rawValue, forKey: key)
  }

  public func encode<T: RawRepresentable>(_ value: T?, forKey key: Key) throws where T.RawValue == Int {
    if let value {
      try encode(value.rawValue, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode<T: RawRepresentable>(_ value: T, forKey key: Key) throws where T.RawValue == String {
    try encode(value.rawValue, forKey: key)
  }

  public func encode<T: RawRepresentable>(_ value: T?, forKey key: Key) throws where T.RawValue == String {
    if let value {
      try encode(value.rawValue, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode<T: RawRepresentable & Encodable>(_ value: T, forKey key: Key) throws where T.RawValue == Int {
    try encode(value.rawValue, forKey: key)
  }

  public func encode<T: RawRepresentable & Encodable>(_ value: T?, forKey key: Key) throws where T.RawValue == Int {
    if let value {
      try encode(value.rawValue, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode<T: RawRepresentable & Encodable>(_ value: T, forKey key: Key) throws where T.RawValue == String {
    try encode(value.rawValue, forKey: key)
  }

  public func encode<T: RawRepresentable & Encodable>(_ value: T?, forKey key: Key) throws where T.RawValue == String {
    if let value {
      try encode(value.rawValue, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }
  
  public func encode(_ value: (some Encodable)?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      writer.values.append(NULL)
      writer.variableNames.append(variableName(forKey: key))
    }
  }

  public func encode<T: FieldSubset & Encodable>(_ value: T, forKey key: Key) throws {
    let subWriter = RowWriter(prefix: prefix + [key.stringValue], parent: writer)
    try value.encode(row: subWriter.encoder(keyedBy: T.Columns.self))
  }
  
  public func encode<T: FieldSubset>(_ value: T, forKey key: Key) throws {
    let subWriter = RowWriter(prefix: prefix + [key.stringValue], parent: writer)
    try value.encode(row: subWriter.encoder(keyedBy: T.Columns.self))
  }
}
