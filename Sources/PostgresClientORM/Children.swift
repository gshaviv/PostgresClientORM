//
//  File.swift
//
//
//  Created by Guy Shaviv on 31/10/2023.
//

import Foundation
import PostgresClientKit

public class Children<Child: TableObject>: Sequence, Codable {
  public typealias AsyncIterator = Children<Child>
  public typealias Element = Child
  public let referencingColumn: Child.Columns
  public var loadedValues: [Child]?
  let sortKey: ColumnName?
  let sortDir: SQLQuery<Child>.OrderBy
  
  public init(ofType childType: Child.Type, by childCol: Child.Columns, sortBy: ColumnName? = nil, order: SQLQuery<Child>.OrderBy = .ascending) {
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
  
  public func load(parentId: PostgresValueConvertible) async throws {
    var query = Child.select()
      .where {
        Child.column(self.referencingColumn) == parentId
      }
    
    if let sortKey {
      query = query.orderBy(sortKey, direction: sortDir)
    }
    
    loadedValues = try await query
      .execute()
  }
  
  public var count: Int { values.count }
  
  public func reset() {
    loadedValues = nil
  }
  
  public func reload(parentId: PostgresValueConvertible) async throws {
    reset()
    try await load(parentId: parentId)
  }

  public func makeIterator() -> Array<Child>.Iterator {
    values.makeIterator()
  }
}

public class Parent<DAD: TableObject>: Codable {
  public var id: DAD.IDType
  public var value: DAD?
    
  public init(id: DAD.IDType) {
    self.id = id
    self.value = nil
  }
  
  public init(value: DAD) throws {
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
  
  public func get() async throws {
    guard value == nil else { return }
    value = try await DAD.fetch(id: id)
  }
}
