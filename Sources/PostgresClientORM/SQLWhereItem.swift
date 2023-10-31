//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresClientKit

public struct SQLWhereItem: ExpressibleByStringLiteral, LosslessStringConvertible {
  private var expression: String
  public var description: String { expression }

  public init(stringLiteral value: String) {
    expression = value
  }

  public init(_ value: String) {
    expression = value
  }
}

public func Or(@ArrayBuilder<SQLWhereItem> _ conditions: () -> [SQLWhereItem]) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: "(\(conditions().map(\.description).joined(separator: " OR ")))")
}

public func And(@ArrayBuilder<SQLWhereItem> _ conditions: () -> [SQLWhereItem]) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: "(\(conditions().map(\.description).joined(separator: " AND ")))")
}

public func == (lhs: ColumnName, rhs: some PostgresValueConvertible) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: rhs is QuoteSQLValue ? "\(lhs) = '\(rhs.postgresValue)'" : "\(lhs) = \(rhs.postgresValue)")
}

public func < (lhs: ColumnName, rhs: some PostgresValueConvertible) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: rhs is QuoteSQLValue ? "\(lhs) < '\(rhs.postgresValue)'" : "\(lhs) = \(rhs.postgresValue)")
}

public func <= (lhs: ColumnName, rhs: some PostgresValueConvertible) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: rhs is QuoteSQLValue ? "\(lhs) <= '\(rhs.postgresValue)'" : "\(lhs) = \(rhs.postgresValue)")
}

public func > (lhs: ColumnName, rhs: some PostgresValueConvertible) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: rhs is QuoteSQLValue ? "\(lhs) > '\(rhs.postgresValue)'" : "\(lhs) = \(rhs.postgresValue)")
}

public func >= (lhs: ColumnName, rhs: some PostgresValueConvertible) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: rhs is QuoteSQLValue ? "\(lhs) >= '\(rhs.postgresValue)'" : "\(lhs) = \(rhs.postgresValue)")
}

public func != (lhs: ColumnName, rhs: some PostgresValueConvertible) -> SQLWhereItem {
  SQLWhereItem(stringLiteral: rhs is QuoteSQLValue ? "\(lhs) <> '\(rhs.postgresValue)'" : "\(lhs) = \(rhs.postgresValue)")
}
