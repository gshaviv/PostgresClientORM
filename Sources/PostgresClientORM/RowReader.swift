//
//  RowReader.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PerfectPostgreSQL

public protocol RowDecodable {}
extension Int: RowDecodable {}
extension Int8: RowDecodable {}
extension Int16: RowDecodable {}
extension Int32: RowDecodable {}
extension Int64: RowDecodable {}
extension UInt: RowDecodable {}
extension UInt8: RowDecodable {}
extension UInt16: RowDecodable {}
extension UInt32: RowDecodable {}
extension UInt64: RowDecodable {}
extension String: RowDecodable {}
extension Double: RowDecodable {}
extension Float: RowDecodable {}
extension Bool: RowDecodable {}

struct RowReader {
  private let prefix: [String]
  private let row: ResultRow

  init(row: ResultRow) {
    self.row = row
    prefix = []
  }

  init(prefix: [String], row: ResultRow) {
    self.row = row
    self.prefix = prefix
  }

  /// Decocde an instance of given type
  /// - Parameter type: the type to decoce
  /// - Returns: An instance of type
  public func decode<T: FieldSubset>(_: T.Type) throws -> T {
    try T(row: decoder(keyedBy: T.Columns.self))
  }

  func decoder<Key>(keyedBy _: Key.Type) -> RowDecoder<Key> where Key: CodingKey {
    RowDecoder(prefix: prefix, row: row)
  }
}

/// A row decoder keywe by a Column type
public struct RowDecoder<Key: CodingKey> {
  let prefix: [String]
  let row: ResultRow

  init(prefix: [String] = [], row: ResultRow) {
    self.row = row
    self.prefix = prefix
  }

  public func decode<T: RawRepresentable>(_: T.Type, forKey key: Key) throws -> T where T.RawValue == Int {
    guard let value = try T(rawValue: decode(T.RawValue.self, forKey: key)) else {
      throw TableObjectError.general("error decoding type \(type(of: T.self))")
    }
    return value
  }

  public func decode<T: RawRepresentable>(_: T?.Type, forKey key: Key) throws -> T? where T.RawValue == String {
    guard let value = try T(rawValue: decode(T.RawValue.self, forKey: key)) else {
      return nil
    }
    return value
  }

  public func decode<T: Decodable>(_: T.Type, forKey key: Key) throws -> T {
    let str = try row.value(ofType: String.self, forKey: key, path: prefix)
    if !CharacterSet(charactersIn: str).subtracting(CharacterSet(charactersIn: "0123456789.")).isEmpty, !str.hasPrefix("["), !str.hasPrefix("{") {
      guard let data = "\"\(str)\"".data(using: .utf8) else {
        throw TableObjectError.general("Value for key: \(key) -> \(str) cannot be converted to data")
      }
      return try JSONDecoder().decode(T.self, from: data)
    }
    guard let data = str.data(using: .utf8) else {
      throw TableObjectError.general("Value for key: \(key) -> \(str) cannot be converted to data")
    }
    return try JSONDecoder().decode(T.self, from: data)
  }

  public func decode<T: Decodable & LosslessStringConvertible>(_: T.Type, forKey key: Key) throws -> T {
    var str = try row.value(ofType: String.self, forKey: key, path: prefix)
    switch str {
    case "t": str = "true"
    case "f": str = "false"
    default:
      break
    }
    guard let v = T(str) else {
      throw TableObjectError.general("Can't convert value for \(key.stringValue): \(str)")
    }
    return v
  }
  
  public func decode<T: Decodable & LosslessStringConvertible>(_: T?.Type, forKey key: Key) throws -> T? {
    guard try !row.isNull(key: key, path: prefix) else {
      return nil
    }
    var str = try row.value(ofType: String.self, forKey: key, path: prefix)
    switch str {
    case "t": str = "true"
    case "f": str = "false"
    default:
      break
    }
    guard let v = T(str) else {
      throw TableObjectError.general("Can't convert value for \(key.stringValue): \(str)")
    }
    return v
  }

  public func decode<T: Decodable & FieldSubset>(_ type: T.Type, forKey key: Key) throws -> T {
    let reader = RowReader(prefix: prefix + [key.stringValue], row: row)
    return try reader.decode(type)
  }

  public func decode<T: FieldSubset>(_ type: T.Type, forKey key: Key) throws -> T {
    let reader = RowReader(prefix: prefix + [key.stringValue], row: row)
    return try reader.decode(type)
  }

  public func decode<T: Decodable>(_: T?.Type, forKey key: Key) throws -> T? {
    guard try !row.isNull(key: key, path: prefix) else {
      return nil
    }
    return try decode(T.self, forKey: key)
  }

  public func contains(_ key: Key) -> Bool {
    row.contains(key: key, path: prefix)
  }

  public func decode(_: Int.Type, forKey key: Key) throws -> Int {
    try row.value(ofType: Int.self, forKey: key, path: prefix)
  }

  public func decode(_: String.Type, forKey key: Key) throws -> String {
    try row.value(ofType: String.self, forKey: key, path: prefix)
  }

  public func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
    try row.value(ofType: Bool.self, forKey: key, path: prefix)
  }
   
//  public func  decode(_: Date.Type, forKey key: Key) throws -> Date {
//    let str = try row.value(ofType: String.self, forKey: key)
//    let formatter = DateFormatter()
//    formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
//    guard let d = formatter.date(from: str) else {
//      throw TableObjectError.general("Can't convert string \"\(str)\" to date")
//    }
//    return d
//  }

  public func decode(_: Double.Type, forKey key: Key) throws -> Double {
    try row.value(ofType: Double.self, forKey: key, path: prefix)
  }

  public func decode(_: Float.Type, forKey key: Key) throws -> Float {
    try row.value(ofType: Float.self, forKey: key, path: prefix)
  }

  public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try row.value(ofType: type, forKey: key, path: prefix)
  }

  public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    try row.value(ofType: type, forKey: key, path: prefix)
  }

  public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    try row.value(ofType: type, forKey: key, path: prefix)
  }

  public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try row.value(ofType: type, forKey: key, path: prefix)
  }

  public func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
    let str = try row.value(ofType: String.self, forKey: key, path: prefix)
    guard let v = UInt(str) else {
      throw TableObjectError.general("Value for key: \(key)")
    }
    return v
  }

  public func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
    let str = try row.value(ofType: String.self, forKey: key, path: prefix)
    guard let v = UInt16(str) else {
      throw TableObjectError.general("Value for key: \(key)")
    }
    return v
  }

  public func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
    let str = try row.value(ofType: String.self, forKey: key, path: prefix)
    guard let v = UInt32(str) else {
      throw TableObjectError.general("Value for key: \(key)")
    }
    return v
  }

  public func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
    let str = try row.value(ofType: String.self, forKey: key, path: prefix)
    guard let v = UInt64(str) else {
      throw TableObjectError.general("Value for key: \(key)")
    }
    return v
  }
}
