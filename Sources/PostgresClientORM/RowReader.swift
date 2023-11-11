//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresClientKit

public struct RowReader {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  let columnMap: [String: Int]
  let values: [PostgresValue]
  
  init(columns: [String], row: Row) {
    columnMap = columns.enumerated().reduce(into: [String: Int]()) {
      $0[$1.element] = $1.offset
    }
    values = row.columns
  }
  
  init(columnMap: [String: Int], values: [PostgresValue]) {
    self.columnMap = columnMap
    self.values = values
  }
  
  public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
    KeyedDecodingContainer(KeyedRowDecodingContainer<Key>(codingPath: codingPath, allKeys: [], values: values, columnMap: columnMap))
  }
  
  public func decode<T: FieldSubset>(_ type: T.Type) throws -> T {
    try T(row: self)
  }
}

public struct KeyedRowDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
  public typealias Key = K
  public var codingPath: [CodingKey]
  public var allKeys: [Key]
  let values: [PostgresValue]
  let columnMap: [String: Int]
  
  public func contains(_ key: Key) -> Bool {
    columnMap.keys.contains(key.stringValue)
  }
  
  public func decodeNil(forKey key: Key) throws -> Bool {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(NSNull.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return values[idx].isNull
  }
  
  public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(Bool.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return try values[idx].bool()
  }
  
  public func decode(_ type: String.Type, forKey key: Key) throws -> String {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(NSNull.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return try values[idx].string()
  }
  
  public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(NSNull.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return try values[idx].double()
  }
  
  public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    guard let v = try Float(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Float.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    guard let v = try Int(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    guard let v = try Int8(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int8.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    guard let v = try Int16(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int16.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    guard let v = try Int32(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int32.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    guard let v = try Int64(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int64.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    guard let v = try UInt(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    guard let v = try UInt8(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt8.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    guard let v = try UInt16(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt16.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    guard let v = try UInt32(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt32.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    guard let v = try UInt64(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt64.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  public func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
    if let type = type as? any FieldSubset.Type {
      let mapSubset = columnMap.reduce(into: [String: Int]()) {
        if $1.key.hasPrefix("\(key.stringValue)_") {
          let tail = String($1.key[$1.key.index($1.key.startIndex, offsetBy: key.stringValue.count + 1)...])
          $0[tail] = $1.value
        }
      }
      let dec = RowReader(columnMap: mapSubset, values: values)
      guard let v = try dec.decode(type) as? T else {
        fatalError("strange?")
      }
      return v
    } else {
      guard let data = try decode(String.self, forKey: key).data(using: .utf8) else {
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
      }
      guard let str = String(data: data, encoding: .utf8) else {
        throw TableObjectError.general("Invalied data for key: \(key.stringValue)")
      }
      if !str.hasPrefix("{") && !str.hasPrefix("["), Double(str) == nil, let data = "\"\(str)\"".data(using: .utf8) {
        return try JSONDecoder().decode(type, from: data)
      }
      return try JSONDecoder().decode(type, from: data)
    }
  }
  
  public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    fatalError("unsupported")
  }
  
  public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    fatalError("unsupported")
  }
  
  public func superDecoder() throws -> Decoder {
    fatalError("Unsupported")
  }
  
  public func superDecoder(forKey key: Key) throws -> Decoder {
    fatalError("Unsupported")
  }
}
