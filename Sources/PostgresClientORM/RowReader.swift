//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresNIO

public struct RowReader {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  let prefix: String
  let row: PostgresRandomAccessRow
  
  init(row: PostgresRow) {
    self.row = PostgresRandomAccessRow(row)
    prefix = ""
  }
  
  init(prefix: String, row: PostgresRandomAccessRow) {
    self.row = row
    self.prefix = prefix.isEmpty ? "" : "\(prefix)_"
  }
  
  public func decode<T: FieldSubset>(_ type: T.Type) throws -> T {
    try T(row: self)
  }
  
  public func decoder<Key>(keyedBy: Key.Type) -> RowDecoder<Key> where Key: CodingKey {
    RowDecoder(prefix: prefix, row: row)
  }
}

public struct RowDecoder<Key: CodingKey> {
  let prefix: String
  let row: PostgresRandomAccessRow
  
  init(prefix: String, row: PostgresRandomAccessRow) {
    self.row = row
    self.prefix = prefix.isEmpty ? "" : "\(prefix)_"
  }
  
  public func callAsFunction<T>(_ type: T.Type, forKey key: Key) throws -> T where T: PostgresDecodable {
    try row[prefix, key].decode(type)
  }
  
  public func callAsFunction<T>(_ type: T.Type, forKey key: Key) throws -> T where T: FieldSubset {
    let reader = RowReader(prefix: prefix + key.stringValue, row: row)
    return try reader.decode(type)
  }

  public func contains(_ key: Key) -> Bool {
    row.contains(prefix: prefix, key: key)
  }
  
  public func callAsFunction(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try Int8(row[prefix, key].decode(Int.self))
  }
  
  public func callAsFunction(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try UInt(row[prefix, key].decode(Int.self))
  }
  
  public func callAsFunction(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try UInt16(row[prefix, key].decode(Int.self))
  }
  
  public func callAsFunction(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try UInt32(row[prefix, key].decode(Int.self))
  }
  
  public func callAsFunction(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try UInt64(row[prefix, key].decode(Int64.self))
  }
  
  public func callAsFunction(_ type: Int8?.Type, forKey key: Key) throws -> Int8? {
    try? self(Int8.self, forKey: key)
  }
  
  public func callAsFunction(_ type: UInt?.Type, forKey key: Key) throws -> UInt? {
    try? self(UInt.self, forKey: key)
  }
  
  public func callAsFunction(_ type: UInt16?.Type, forKey key: Key) throws -> UInt16? {
    try? self(UInt16.self, forKey: key)
  }
  
  public func callAsFunction(_ type: UInt32?.Type, forKey key: Key) throws -> UInt32? {
    try? self(UInt32.self, forKey: key)
  }
  
  public func callAsFunction(_ type: UInt64?.Type, forKey key: Key) throws -> UInt64? {
    try? self(UInt64.self, forKey: key)
  }
}

extension PostgresRandomAccessRow {
  subscript(prefix: String, key: CodingKey) -> PostgresCell {
    self[prefix + key.stringValue]
  }
  
  func contains(prefix: String = "", key: CodingKey) -> Bool {
    contains(prefix + key.stringValue)
  }
}
