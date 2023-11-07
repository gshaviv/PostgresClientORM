//
//  File.swift
//
//
//  Created by Guy Shaviv on 26/10/2023.
//

import Foundation
import PostgresClientKit

public class RowWriter {
  public var codingPath: [CodingKey] = []
  public var userInfo: [CodingUserInfoKey: Any] = [:]
  fileprivate var variableNames = [String]()
  fileprivate var values = [String]()
  
  public enum QueryType {
    case insert
    case partialUpdate
  }

  public func container<Key>(keyedBy type: Key.Type) -> TypedRowWriterContainer<Key> where Key: CodingKey {
    TypedRowWriterContainer<Key>(type: type, codingPath: codingPath,
                                 appendValues: { [weak self] name, value in
                                   self?.variableNames.append(name)
                                   self?.values.append(value)
                                 })
  }
  
  public func encode<T: TableObject>(_ value: T, as queryType: RowWriter.QueryType) throws -> SQLQuery<T> {
    try value.encode(row: self)
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

public struct TypedRowWriterContainer<K: CodingKey> {
  var type: K.Type
  public var codingPath: [CodingKey]
  var appendValues: (String, String) -> Void

  public mutating func encodeNil(forKey key: K) throws {
    appendValues(key.stringValue, "NULL")
  }
  
  public mutating func encode(_ value: Bool, forKey key: K) throws {
    try appendValues(key.stringValue, value.postgresValue.string())
  }
  
  public mutating func encode(_ value: String, forKey key: K) throws {
    appendValues(key.stringValue, "'\(value)'")
  }
  
  public mutating func encode(_ value: Double, forKey key: K) throws {
    try appendValues(key.stringValue, value.postgresValue.string())
  }
  
  public mutating func encode(_ value: Float, forKey key: K) throws {
    try appendValues(key.stringValue, Double(value).postgresValue.string())
  }
  
  public mutating func encode(_ value: Int, forKey key: K) throws {
    try appendValues(key.stringValue, value.postgresValue.string())
  }
  
  public mutating func encode(_ value: Int8, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: Int16, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: Int32, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: Int64, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: UInt, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: UInt8, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: UInt16, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: UInt32, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
  
  public mutating func encode(_ value: UInt64, forKey key: K) throws {
    appendValues(key.stringValue, "\(value)")
  }
      
  public mutating func encode(_ value: some FieldSubset, forKey key: K) throws {
    let enc = RowWriter()
    try value.encode(row: enc)
    zip(enc.variableNames, enc.values).forEach {
      appendValues("\(key.stringValue)_\($0.0)", $0.1)
    }
  }
  
  public mutating func encode(_ value: some Encodable, forKey key: K) throws {
    let enc = JSONEncoder()
    let data = try enc.encode(value)
    if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
      appendValues(key.stringValue, "'\(str)'")
    } else {
      throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Invalid JSON"))
    }
  }
}
