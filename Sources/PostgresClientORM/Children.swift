//
//  File.swift
//
//
//  Created by Guy Shaviv on 31/10/2023.
//

import Foundation
import PostgresClientKit

public class Children<Child: TableObject>: AsyncSequence, AsyncIteratorProtocol {
  public typealias AsyncIterator = Children<Child>
  public typealias Element = Child
  public let parentId: PostgresValueConvertible?
  public let referencingColumn: Child.Key
  private var loadedValues: [Child]?
  private var iterator: Array<Child>.Iterator?
  let sortKey: Child.Key?
  let sortDir: SQLQuery<Child>.OrderBy
  
  init(ofType childType: Child.Type, referencing: some TableObject, by childCol: Child.Key, sortBy: Child.Key? = nil, order: SQLQuery<Child>.OrderBy = .ascending) {
    self.parentId = referencing.id
    self.referencingColumn = childCol
    self.sortKey = sortBy
    self.sortDir = order
  }
  
  var values: [Child] {
    loadedValues ?? []
  }
  
  var isLoaded: Bool {
    loadedValues != nil
  }
  
  subscript(idx: Int) -> Child {
    values[idx]
  }
  
  func load() async throws {
    guard let parentId else {
      throw TableObjectError.general("Missing parent id")
    }
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
  
  var loadedCount: Int {
    get async throws {
      if !isLoaded {
        try await load()
      }
      return values.count
    }
  }
  
  var count: Int { values.count }
  
  func reset() {
    loadedValues = nil
  }
  
  func reload() async throws {
    reset()
    try await load()
  }
  
  public func next() async throws -> Child? {
    if !isLoaded {
      try await load()
      iterator = loadedValues?.makeIterator()
    }
    return iterator?.next()
  }
  
  public func makeAsyncIterator() -> Self {
    iterator = loadedValues?.makeIterator()
    return self
  }
}
