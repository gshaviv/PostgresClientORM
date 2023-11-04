//
//  File.swift
//
//
//  Created by Guy Shaviv on 31/10/2023.
//

import Foundation
import PostgresClientKit

public class Children<Child: TableObject>: Sequence {
  public typealias AsyncIterator = Children<Child>
  public typealias Element = Child
  public let referencingColumn: Child.Key
  public var loadedValues: [Child]?
  let sortKey: ColumnName?
  let sortDir: SQLQuery<Child>.OrderBy
  
  public init(ofType childType: Child.Type, by childCol: Child.Key, sortBy: ColumnName? = nil, order: SQLQuery<Child>.OrderBy = .ascending) {
    self.referencingColumn = childCol
    self.sortKey = sortBy
    self.sortDir = order
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
  var parentID: DAD.IDType
  var parent: DAD?
  
  init(id: DAD.IDType) {
    self.parentID = id
    self.parent = nil
  }
  
  init(parent: DAD) throws {
    self.parent = parent
    if let id = parent.id {
      self.parentID = id
    } else {
      throw TableObjectError.general("parent Id == nil")
    }
  }
  
  public required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.parentID = try container.decode(DAD.IDType.self)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(parentID)
  }
  
  var value: DAD? { parent }
  var id: DAD.IDType? { parentID }
  var type: DAD.Type { DAD.self }
  
  func get() async throws {
    guard parent == nil else { return }
    parent = try await DAD.fetch(id: parentID)
  }
}
