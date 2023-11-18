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
  let prefix: [String]
  let row: PostgresRandomAccessRow
  
  init(row: PostgresRow) {
    self.row = PostgresRandomAccessRow(row)
    prefix = []
  }
  
  init(prefix: [String], row: PostgresRandomAccessRow) {
    self.row = row
    self.prefix = prefix
  }
  
  public func decode<T: FieldSubset>(_ type: T.Type) throws -> T {
    try T(row: self.decoder(keyedBy: T.Columns.self))
  }
  
  public func decoder<Key>(keyedBy: Key.Type) -> RowDecoder<Key> where Key: CodingKey {
    RowDecoder(prefix: prefix, row: row)
  }
}

public struct RowDecoder<Key: CodingKey> {
  let prefix: [String]
  let row: PostgresRandomAccessRow
  
  init(prefix: [String] = [], row: PostgresRandomAccessRow) {
    self.row = row
    self.prefix = prefix
  }
  
  public func decode<T: PostgresDecodable>(_ type: T.Type, forKey key: Key) throws -> T {
    try row[path: prefix, key].decode(type)
  }
  
  public func decode<T: RawRepresentable>(_ type: T.Type, forKey key: Key) throws -> T where T.RawValue: PostgresDecodable {
    guard let value = T(rawValue: try decode(T.RawValue.self, forKey: key)) else {
      throw PostgresDecodingError.Code.failure
    }
    return value
  }
  
  public func decode<T: FieldSubset>(_ type: T.Type, forKey key: Key) throws -> T {
    let reader = RowReader(prefix: prefix + [key.stringValue], row: row)
    return try reader.decode(type)
  }

  public func contains(_ key: Key) -> Bool {
    row.contains(path: prefix, key: key)
  }
  
  public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try Int8(row[path: prefix, key].decode(Int.self))
  }
  
  public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try UInt(row[path: prefix, key].decode(Int.self))
  }
  
  public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try UInt16(row[path: prefix, key].decode(Int.self))
  }
  
  public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try UInt32(row[path: prefix, key].decode(Int.self))
  }
  
  public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try UInt64(row[path: prefix, key].decode(Int64.self))
  }
  
  public func decode(_ type: Int8?.Type, forKey key: Key) throws -> Int8? {
    try? decode(Int8.self, forKey: key)
  }
  
  public func decode(_ type: UInt?.Type, forKey key: Key) throws -> UInt? {
    try? decode(UInt.self, forKey: key)
  }
  
  public func decode(_ type: UInt16?.Type, forKey key: Key) throws -> UInt16? {
    try? decode(UInt16.self, forKey: key)
  }
  
  public func decode(_ type: UInt32?.Type, forKey key: Key) throws -> UInt32? {
    try? decode(UInt32.self, forKey: key)
  }
  
  public func decode(_ type: UInt64?.Type, forKey key: Key) throws -> UInt64? {
    try? decode(UInt64.self, forKey: key)
  }
}

extension PostgresRandomAccessRow {
  subscript(path prefix: [String], key: CodingKey) -> PostgresCell {
    self[(prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")]
  }
  
  func contains(path prefix: [String] = [], key: CodingKey) -> Bool {
    contains((prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_"))
  }
}
