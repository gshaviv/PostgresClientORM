//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresClientKit

public struct QueryResults<Type: FieldCodable>: Sequence, IteratorProtocol {
  private let connection: Connection
  private let statement: Statement
  private let cursor: Cursor
  private var names: [String] = []

  init(query: SQLQuery<Type>) async throws {
    connection = try await ConnectionGroup.shared.obtain()
    statement = try connection.prepareStatement(text: query.sqlString)
    cursor = try statement.execute(retrieveColumnMetadata: true)
    if let names = cursor.columns?.map(\.name) {
      self.names = names
    } else {
      names = []
    }
  }

  public func next() -> Type? {
    guard !names.isEmpty else {
      ConnectionGroup.shared.release(connection: connection)
      return nil
    }
    guard let result = cursor.next() else {
      ConnectionGroup.shared.release(connection: connection)
      return nil
    }
    switch result {
    case let .success(row):
      do {
        let decoder = RowReader(columns: names, row: row)
        let v = try decoder.decode(Type.self)
        if let v = v as? any TableObject {
          v.dbHash = try v.calculcateDbHash()
        }
        return v
      } catch {
        ConnectionGroup.shared.release(connection: connection)
        return nil
      }
    case .failure:
      ConnectionGroup.shared.release(connection: connection)
      return nil
    }
  }
}
