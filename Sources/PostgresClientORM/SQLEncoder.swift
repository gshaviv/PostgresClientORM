//
//  File.swift
//
//
//  Created by Guy Shaviv on 26/10/2023.
//

import Foundation
import PostgresClientKit

class SQLEncoder: Encoder {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  fileprivate var variableNames = [String]()
  fileprivate var values = [String]()
  
  enum QueryType {
    case insert
    case partialUpdate
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    KeyedEncodingContainer(
      SQLKeyedEncodingContainer(codingPath: codingPath,
                                appendValues: { [weak self] name, value in
                                  self?.variableNames.append(name)
                                  self?.values.append(value)
                                }, parentEncoderGetter: { [unowned self] in
                                  self
                                })
    )
  }
  
  func unkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("Unsupported")
  }
  
  func singleValueContainer() -> SingleValueEncodingContainer {
    fatalError("Unsupported")
  }
  
  func encode<T: TableObject>(_ value: T, as queryType: SQLEncoder.QueryType) throws -> SQLQuery<T> {
    try value.encode(to: self)
    switch queryType {
    case .insert:
      return SQLQuery(base: "INSERT INTO \(T.tableName) (\(variableNames.joined(separator: ","))) VALUES (\(values.joined(separator: ",")))")
      
    case .partialUpdate:
      if let idIdx = variableNames.firstIndex(where: { $0 == T.idColumn.name }) {
        variableNames.remove(at: idIdx)
        values.remove(at: idIdx)
      }
      return SQLQuery(base: "UPDATE \(T.tableName) SET \(zip(variableNames, values).map { "\($0.0) = \($0.1)" }.joined(separator: ","))")
    }
  }
}

private struct SQLKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
  typealias Key = K
  var codingPath: [CodingKey]
  var appendValues: (String, String) -> Void
  var parentEncoderGetter: () -> Encoder

  mutating func encodeNil(forKey key: K) throws {
    appendValues(key.stringValue, "NULL")
  }
  
  mutating func encode(_ value: Bool, forKey key: K) throws {
    try appendValues(key.stringValue, value.postgresValue.string())
  }
  
  mutating func encode(_ value: String, forKey key: K) throws {
    appendValues(key.stringValue, "'\(value)'")
  }
  
  mutating func encode(_ value: Double, forKey key: K) throws {
    try appendValues(key.stringValue, value.postgresValue.string())
  }
  
  mutating func encode(_ value: Float, forKey key: K) throws {
    try appendValues(key.stringValue, Double(value).postgresValue.string())
  }
  
  mutating func encode(_ value: Int, forKey key: K) throws {
    try appendValues(key.stringValue, value.postgresValue.string())
  }
  
  mutating func encode(_ value: Int8, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: Int16, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: Int32, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: Int64, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: UInt, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: UInt8, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: UInt16, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: UInt32, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  mutating func encode(_ value: UInt64, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
      
  mutating func encode(_ value: some Encodable, forKey key: K) throws {
    if  value is any FieldGroup {
      let enc = SQLEncoder()
      try value.encode(to: enc)
      zip(enc.variableNames, enc.values).forEach {
        appendValues("\(key.stringValue)_\($0.0)", $0.1)
      }
    } else {
      let enc = JSONEncoder()
      let data = try enc.encode(value)
      if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
        appendValues(key.stringValue, "'\(str)'")
      } else {
        throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Invalid JSON"))
      }
    }
  }
  
  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
    fatalError("Unsupported")
  }
  
  mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
    fatalError("Unsupported")
  }
  
  mutating func superEncoder() -> Encoder {
    parentEncoderGetter()
  }
  
  mutating func superEncoder(forKey key: K) -> Encoder {
    parentEncoderGetter()
  }
}
