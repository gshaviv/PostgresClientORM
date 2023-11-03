//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresClientKit

public struct SQLQuery<TYPE: Codable> {
  let base: String
  var filter: [String] = []
  var extras: [String] = []
  var transaction: UUID? = nil

  public init(base: String, filter: [String] = [], extras: [String] = [], in transaction: UUID? = nil) {
    self.base = base
    self.filter = filter
    self.extras = extras
    self.transaction = transaction
  }

  public var sqlString: String {
    var elements = [base]
    if !filter.isEmpty {
      elements.append("WHERE \(filter.joined(separator: " AND "))")
    }
    elements += extras
    return elements.joined(separator: " ")
  }

  @discardableResult public func execute() async throws -> [TYPE] {
    try await DatabaseActor.shared.execute(sqlQuery: self)
  }

  public func `where`(@ArrayBuilder<SQLWhereItem> _ expr: () -> [SQLWhereItem]) -> Self {
    SQLQuery(base: base, filter: filter + expr().map(\.description), extras: extras, in: transaction)
  }

  public func limit(_ n: Int) -> SQLQuery<TYPE> {
    SQLQuery(base: base, filter: filter, extras: extras + ["LIMIT \(n)"], in: transaction)
  }

  public enum OrderBy: String {
    case ascending = "ASC"
    case descending = "DESC"
  }

  public func orderBy(_ columns: ColumnName..., direction: OrderBy = .ascending) -> Self {
    SQLQuery(base: base, filter: filter, extras: extras + ["ORDER BY \(columns.map(\.name).joined(separator: ",")) \(direction == .descending ? direction.rawValue : "")"], in: transaction)
  }

  public func orderBy(_ pairs: (ColumnName, OrderBy)...) -> Self {
    SQLQuery(base: base, filter: filter, extras: extras + ["ORDER BY \(pairs.map { "\($0.0.name) \($0.1.rawValue)" }.joined(separator: ","))"], in: transaction)
  }

  public func transaction(_ id: UUID?) -> Self {
    if let id {
      return SQLQuery(base: base, filter: filter, extras: extras, in: id)
    } else {
      return self
    }
  }

  public var results: QueryResults<TYPE> {
    get async throws {
      try await QueryResults(query: self)
    }
  }
}

extension SQLQuery: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    base = value
  }
}

extension PostgresValueConvertible {
  var sqlString: String {
    self is QuoteSQLValue ? "'\(postgresValue)'" : "\(postgresValue)"
  }
}

protocol QuoteSQLValue {}

extension String: QuoteSQLValue {}

extension UUID: PostgresValueConvertible, QuoteSQLValue {
  public var postgresValue: PostgresClientKit.PostgresValue {
    PostgresValue(uuidString)
  }
}

extension PostgresClientKit.ConnectionConfiguration {
  mutating func set(url: String) {
    guard let components = URLComponents(string: url) else {
      return
    }
    if let host = components.host {
      self.host = host
    }
    if let db = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).components(separatedBy: "/").first {
      database = db
    }
    if let user = components.user {
      self.user = user
    }
    if let password = components.password {
      credential = .scramSHA256(password: password)
    }
    if components.queryItems?.filter({ $0.name.lowercased() == "sslmode" }).first?.value == "disable" {
      ssl = false
    } else {
      ssl = true
    }
    if let port = components.port {
      self.port = port
    }
  }
}
