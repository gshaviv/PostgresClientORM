//
//  File.swift
//  
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresClientKit

public actor DatabaseActor {
  public static let shared = DatabaseActor()
  private var activeTransaction: (task: Task<Void, Error>, id: UUID)?

  func getCount(sqlQuery: SQLQuery<CountRetrieval>) async throws -> Int {
    if let activeTransaction, activeTransaction.id != sqlQuery.transaction {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    let statement = try connection.prepareStatement(text: sqlQuery.sqlString)
    let cursor = try statement.execute(retrieveColumnMetadata: true)
    guard let row = cursor.next() else {
      throw TableObjectError.general("no count?")
    }
    return try row.get().columns[0].int()
  }

  public func execute<TYPE: FieldSubset>(sqlQuery: SQLQuery<TYPE>) async throws -> [TYPE] {
    if let activeTransaction, activeTransaction.id != sqlQuery.transaction {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    var items = [TYPE]()
    for item in try await sqlQuery.results {
      items.append(item)
    }

    return items
  }
  
  public func execute<TYPE: FieldSubset>(decode: TYPE.Type, _ sqlText: String, transaction id: UUID? = nil) async throws -> [TYPE] {
    if let activeTransaction, activeTransaction.id != id {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    let statement = try connection.prepareStatement(text: sqlText)
    let cursor = try statement.execute(retrieveColumnMetadata: true)
    
    guard let names = cursor.columns?.map(\.name) else {
      return []
    }
    
    var items = [TYPE]()
    
    for row in cursor {
      let decoder = RowReader(columns: names, row: try row.get())
      let v = try decoder.decode(TYPE.self)
      
      if let v = v as? any TableObject {
        v.dbHash = try v.calculcateDbHash()
      }
      items.append(v)
    }

    return items
  }


  public func execute(_ sqlText: String, transaction id: UUID? = nil) async throws {
    if let activeTransaction, activeTransaction.id != id {
      try await activeTransaction.task.value
    }
    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    let statement = try connection.prepareStatement(text: sqlText)
    _ = try statement.execute(retrieveColumnMetadata: true)
  }

  public func transaction(_ transactionBlock: @escaping (_ transactionId: UUID) async throws -> Void) async throws {
    if let activeTransaction {
      try await activeTransaction.task.value
    }

    let connection = try await ConnectionGroup.shared.obtain()
    defer {
      ConnectionGroup.shared.release(connection: connection)
    }

    let tid = UUID()
    activeTransaction = (task: Task<Void, Error> {
      try connection.beginTransaction()
      do {
        try await transactionBlock(tid)
        try connection.commitTransaction()
      } catch {
        try connection.rollbackTransaction()
      }
      self.activeTransaction = nil
    }, id: tid)

    try await activeTransaction?.task.value
  }
}
