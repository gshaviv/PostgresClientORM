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
  let sortKey: Child.Key?
  let sortDir: SQLQuery<Child>.OrderBy
  
  public init(ofType childType: Child.Type, by childCol: Child.Key, sortBy: Child.Key? = nil, order: SQLQuery<Child>.OrderBy = .ascending) {
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
