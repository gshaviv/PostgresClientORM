//
//  File.swift
//
//
//  Created by Guy Shaviv on 26/10/2023.
//

import Foundation
import PostgresNIO

public class RowWriter {
  public var codingPath: [CodingKey] = []
  public var userInfo: [CodingUserInfoKey: Any] = [:]
  fileprivate var variableNames = [String]()
  fileprivate var values = [PostgresEncodable?]()
  private let prefix: [String]
  private weak var parentWriter: RowWriter?
  
  init(prefix: [String] = [], parent: RowWriter? = nil) {
    self.prefix = prefix
    self.parentWriter = parent
  }
  
  public enum QueryType {
    case insert
    case update
    case updateColumns([ColumnName])
  }
  
  public func encoder<Key>(keyedBy tape: Key.Type) -> RowEncoder<Key> where Key: CodingKey {
    RowEncoder(prefix: prefix, writer: parentWriter ?? self)
  }
  
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
    case .updateColumns(let cols):
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

public struct RowEncoder<Key: CodingKey> {
  let prefix: [String]
  let writer: RowWriter
  
  init(prefix: [String] = [], writer: RowWriter) {
    self.prefix = prefix
    self.writer = writer
  }
  
  private func variableName(forKey key: Key) -> String {
    (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
  }
  
  public func encode<T>(_ value: T, forKey key: Key) throws where T: PostgresEncodable {
    writer.values.append(value)
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode<T>(_ value: T, forKey key: Key) throws where T: RawRepresentable, T.RawValue: PostgresEncodable {
    try encode(value.rawValue, forKey: key)
  }
  
  public func encode<T>(_ value: Optional<T>, forKey key: Key) throws where T: PostgresEncodable {
    if let value {
      writer.values.append(value)
      writer.variableNames.append(variableName(forKey: key))
    }
  }
  
  public func encode<T>(_ value: T, forKey key: Key) throws where T: FieldSubset {
    let subWriter = RowWriter(prefix: prefix + [key.stringValue], parent: writer)
    try value.encode(row: subWriter.encoder(keyedBy: T.Columns.self))
  }
  
  public func encode(_ value: Int8, forKey key: Key) throws {
    writer.values.append(Int(value))
    writer.variableNames.append(variableName(forKey: key))
  }
  
  public func encode(_ value: Int8?, forKey key: Key) throws {
    if let value {
      writer.variableNames.append(variableName(forKey: key))
      writer.values.append(Int(value))
    }
  }
}

