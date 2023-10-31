//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresClientKit

struct SQLDecoder: Decoder {
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
  
  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
    KeyedDecodingContainer(SQLKeyedDecodingContainer<Key>(codingPath: codingPath, allKeys: [], values: values, columnMap: columnMap) {
      self
    })
  }
  
  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    fatalError("Unsupported")
  }
  
  func singleValueContainer() throws -> SingleValueDecodingContainer {
    guard values.count == 1 else {
      throw TableObjectError.general("Can't request single value container with multiple returned values")
    }
    return SQLSingleValueDecodingContainer(codingPath: codingPath, value: values[0])
  }
  
  public func decode<T: Decodable>(_ type: T.Type) throws -> T {
    try T(from: self)
  }
}

private struct SQLSingleValueDecodingContainer: SingleValueDecodingContainer {
  var codingPath: [CodingKey]
  var value: PostgresValue
  
  func decodeNil() -> Bool {
    value.isNull
  }
  
  func decode(_ type: Bool.Type) throws -> Bool {
    try value.bool()
  }
  
  func decode(_ type: String.Type) throws -> String {
    try value.string()
  }
  
  func decode(_ type: Double.Type) throws -> Double {
    try value.double()
  }
  
  private func decodeValue<T: LosslessStringConvertible>() throws -> T {
    guard let v = try T(value.string()) else {
      throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type(of: T.self))"))
    }
    return v
  }
  
  func decode(_ type: Float.Type) throws -> Float {
    try decodeValue()
  }
  
  func decode(_ type: Int.Type) throws -> Int {
    try value.int()
  }
  
  func decode(_ type: Int8.Type) throws -> Int8 {
    try decodeValue()
  }
  
  func decode(_ type: Int16.Type) throws -> Int16 {
    try decodeValue()
  }
  
  func decode(_ type: Int32.Type) throws -> Int32 {
    try decodeValue()
  }
  
  func decode(_ type: Int64.Type) throws -> Int64 {
    try decodeValue()
  }
  
  func decode(_ type: UInt.Type) throws -> UInt {
    try decodeValue()
  }
  
  func decode(_ type: UInt8.Type) throws -> UInt8 {
    try decodeValue()
  }
  
  func decode(_ type: UInt16.Type) throws -> UInt16 {
    try decodeValue()
  }
  
  func decode(_ type: UInt32.Type) throws -> UInt32 {
    try decodeValue()
  }
  
  func decode(_ type: UInt64.Type) throws -> UInt64 {
    try decodeValue()
  }
  
  func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    guard let data = try decode(String.self).data(using: .utf8) else {
      throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "failed to read column"))
    }
    guard let str = String(data: data, encoding: .utf8) else {
      throw TableObjectError.general("Invalied data")
    }
    if !str.hasPrefix("{") || !str.hasPrefix("["), let data = "\"\(str)\"".data(using: .utf8) {
      return try JSONDecoder().decode(type, from: data)
    }
    return try JSONDecoder().decode(type, from: data)
  }
}

private struct SQLKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
  typealias Key = K
  var codingPath: [CodingKey]
  var allKeys: [Key]
  let values: [PostgresValue]
  let columnMap: [String: Int]
  var parentDecoderGetter: () -> Decoder
  
  func contains(_ key: Key) -> Bool {
    columnMap.keys.contains(key.stringValue)
  }
  
  func decodeNil(forKey key: Key) throws -> Bool {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(NSNull.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return values[idx].isNull
  }
  
  func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(Bool.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return try values[idx].bool()
  }
  
  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(NSNull.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return try values[idx].string()
  }
  
  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    guard let idx = columnMap[key.stringValue], idx < values.count else {
      throw DecodingError.valueNotFound(NSNull.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return try values[idx].double()
  }
  
  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    guard let v = try Float(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Float.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    guard let v = try Int(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    guard let v = try Int8(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int8.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    guard let v = try Int16(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int16.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    guard let v = try Int32(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int32.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    guard let v = try Int64(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(Int64.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    guard let v = try UInt(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    guard let v = try UInt8(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt8.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    guard let v = try UInt16(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt16.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    guard let v = try UInt32(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt32.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    guard let v = try UInt64(decode(String.self, forKey: key)) else {
      throw DecodingError.typeMismatch(UInt64.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
    }
    return v
  }
  
  func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
    if type is any FieldGroup.Type {
      let mapSubset = columnMap.reduce(into: [String: Int]()) {
        if $1.key.hasPrefix("\(key.stringValue)_") {
          let tail = String($1.key[$1.key.index($1.key.startIndex, offsetBy: key.stringValue.count + 1)...])
          $0[tail] = $1.value
        }
      }
      let dec = SQLDecoder(columnMap: mapSubset, values: values)
      return try dec.decode(type)
    } else {
      guard let data = try decode(String.self, forKey: key).data(using: .utf8) else {
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath + [key], debugDescription: key.stringValue))
      }
      guard let str = String(data: data, encoding: .utf8) else {
        throw TableObjectError.general("Invalied data for key: \(key.stringValue)")
      }
      if !str.hasPrefix("{") || !str.hasPrefix("["), let data = "\"\(str)\"".data(using: .utf8) {
        return try JSONDecoder().decode(type, from: data)
      }
      return try JSONDecoder().decode(type, from: data)
    }
  }
  
  func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    fatalError("unsupported")
  }
  
  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    fatalError("unsupported")
  }
  
  func superDecoder() throws -> Decoder {
    parentDecoderGetter()
  }
  
  func superDecoder(forKey key: Key) throws -> Decoder {
    parentDecoderGetter()
  }
}
