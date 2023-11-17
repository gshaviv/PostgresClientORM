//
//  File.swift
//
//
//  Created by Guy Shaviv on 31/10/2023.
//

import Foundation
import PostgresNIO

public class Children<Child: TableObject>: Sequence, Codable {
  public typealias AsyncIterator = Children<Child>
  public typealias Element = Child
  public let referencingColumn: Child.Columns
  public private(set) var loadedValues: [Child]?
  let sortKey: ColumnName?
  let sortDir: Query<Child>.OrderBy
  
  public init(ofType childType: Child.Type, by childCol: Child.Columns, sortBy: ColumnName? = nil, order: Query<Child>.OrderBy = .ascending) {
    self.referencingColumn = childCol
    self.sortKey = sortBy
    self.sortDir = order
  }
  
  public required init(from decoder: Decoder) throws {
    throw TableObjectError.general("Can't decode chiclren")
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    guard let values = values as? any Encodable else {
      throw TableObjectError.general("Children type must be encodable")
    }
    try container.encode(values)
  }
  
  public var values: [Child] {
    loadedValues ?? []
  }
  
  public var isLoaded: Bool {
    loadedValues != nil
  }
  
  public subscript(idx: Int) -> Child {
    values[idx]
  }
  
  public func load(parentId: any PostgresCodable, transaction id: UUID? = nil) async throws {
    var query = try Child.select()
      .where {
        Child.column(self.referencingColumn) == parentId
      }
    
    if let sortKey {
      query = query.orderBy(sortKey, direction: sortDir)
    }
    
    loadedValues = try await query
      .execute(transaction: id)
  }
  
  public var count: Int { values.count }
  
  public func reset() {
    loadedValues = nil
  }
  
  public func reload(parentId: any PostgresCodable) async throws {
    reset()
    try await load(parentId: parentId)
  }

  public func makeIterator() -> Array<Child>.Iterator {
    values.makeIterator()
  }
}

public class Parent<DAD: TableObject>: Codable, FieldSubset {
  public private(set) var id: DAD.IDType
  public private(set) var value: DAD?
    
  public init(_ id: DAD.IDType) {
    self.id = id
    self.value = nil
  }
  
  public init(_ value: DAD) throws {
    self.value = value
    if let id = value.id {
      self.id = id
    } else {
      throw TableObjectError.general("parent Id == nil")
    }
  }
  
  public required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.id = try container.decode(DAD.IDType.self)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(id)
  }
  
  public var type: DAD.Type { DAD.self }
  
  @discardableResult public func get(transaction tid: UUID? = nil) async throws -> DAD {
    if let value {
      return value
    }
    value = try await DAD.fetch(id: id, transaction: tid)
    guard let value else {
      throw TableObjectError.general("Missing parent of type \(type)")
    }
    return value
  }
  
  public enum Columns: String, CodingKey {
    case root = ""
  }
  
  public required init(row: RowReader) throws {
    let decode = row.decoder(keyedBy: Columns.self)
    self.id = try decode(DAD.IDType.self, forKey: .root)
  }
  
  public func encode(row: RowWriter) throws {
    let encode = row.encoder(keyedBy: Columns.self)
    try encode(id, forKey: .root)
  }
}

public class OptionalParent<DAD: TableObject>: Codable, FieldSubset {
   
  
  
  public private(set) var id: DAD.IDType?
  public private(set) var value: DAD?
    
  public init(_ id: DAD.IDType?) {
    self.id = id
    self.value = nil
  }
  
  public init(_ value: DAD?) {
    self.value = value
    self.id = value?.id
  }
  
  public required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.id = try container.decode(DAD.IDType.self)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(id)
  }
  
  public var type: DAD.Type { DAD.self }
  
  @discardableResult public func get(transaction tid: UUID? = nil) async throws -> DAD? {
    guard id != nil else {
      throw TableObjectError.general("Trying to get parent with nil id")
    }
    if let value {
      return value
    }
    value = try await DAD.fetch(id: id, transaction: tid)
    return value
  }
  
  public enum Columns: String, CodingKey {
    case root = ""
  }
  
  public required init(row: RowReader) throws {
    let decode = row.decoder(keyedBy: Columns.self)
    self.id = try decode(DAD.IDType.self, forKey: .root)
  }
  
  public func encode(row: RowWriter) throws {
    let encode = row.encoder(keyedBy: Columns.self)
    try encode(id, forKey: .root)
  }
}

public extension TableObject {
  @discardableResult func loadChildren<ChildType>(_ keypath: KeyPath<Self, Children<ChildType>>, transaction: UUID? = nil) async throws -> [ChildType] {
    guard let id else {
      throw TableObjectError.general("id is nil")
    }
    try await self[keyPath: keypath].load(parentId: id, transaction: transaction)
    return self[keyPath: keypath].values
  }
}
