//
//  ResultRow.swift
//
//
//  Created by Guy Shaviv on 04/01/2024.
//

import Foundation
import PerfectPostgreSQL

struct ResultRow {
  let result: PGResult
  var row: Int
  let fields: [String: Int]

  init(result: PGResult, row: Int) {
    self.result = result
    self.row = row
    fields = (0 ..< result.numFields()).compactMap { result.fieldName(index: $0) }.reduce(into: [String: Int]()) { $0[$1] = $0.count }
  }

  func value(ofType _: String.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> String {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldString(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: String?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> String? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldString(tupleIndex: row, fieldIndex: idx)
  }

  func value(ofType _: Int.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldInt(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: Int?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldInt(tupleIndex: row, fieldIndex: idx)
  }

  func value(ofType _: Int8.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int8 {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldInt8(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: Int8?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int8? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldInt8(tupleIndex: row, fieldIndex: idx)
  }

  func value(ofType _: Int16.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int16 {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldInt16(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: Int16?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int16? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldInt16(tupleIndex: row, fieldIndex: idx)
  }

  func value(ofType _: Int32.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int32 {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldInt32(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: Int32?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int32? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldInt32(tupleIndex: row, fieldIndex: idx)
  }

  func value(ofType _: Int64.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int64 {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldInt64(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: Int64?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Int64? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldInt64(tupleIndex: row, fieldIndex: idx)
  }

  func value(ofType _: Float.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Float {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldFloat(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: Float?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Float? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldFloat(tupleIndex: row, fieldIndex: idx)
  }

  func value(ofType _: Double.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Double {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey], let v = result.getFieldDouble(tupleIndex: row, fieldIndex: idx) else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return v
  }

  func value(ofType _: Double?.Type, forKey key: CodingKey, path prefix: [String] = []) throws -> Double? {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.getFieldDouble(tupleIndex: row, fieldIndex: idx)
  }

  func contains(key: CodingKey, path prefix: [String] = []) -> Bool {
    fields[(prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")] != nil
  }

  func isNull(key: CodingKey, path prefix: [String] = []) throws -> Bool {
    let rowKey = (prefix + [key.stringValue]).filter { !$0.isEmpty }.joined(separator: "_")
    guard let idx = fields[rowKey] else {
      throw TableObjectError.general("key not found \(rowKey)")
    }
    return result.fieldIsNull(tupleIndex: row, fieldIndex: idx)
  }
}
