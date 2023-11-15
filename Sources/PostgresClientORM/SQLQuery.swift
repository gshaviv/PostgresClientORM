//
//  File.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PostgresNIO

public struct Query<TYPE: FieldSubset> {
  let sqlString: String
  let bindings: PostgresBindings

  var postgresQuery: PostgresQuery {
    PostgresQuery(unsafeSQL: self.sqlString, binds: self.bindings)
  }

  init(_ sql: String, _ variables: PostgresEncodable?...) throws {
    self.sqlString = sql
    var bind = PostgresBindings()
    for item in variables {
      if let item {
        try bind.append(item)
      } else {
        bind.appendNull()
      }
    }
    self.bindings = bind
  }

  init(sql: String, variables: [PostgresEncodable?]) throws {
    self.sqlString = sql
    var bind = PostgresBindings()
    for item in variables {
      if let item {
        try bind.append(item)
      } else {
        bind.appendNull()
      }
    }
    self.bindings = bind
  }

  init(sql: String) {
    self.sqlString = sql
    self.bindings = PostgresBindings()
  }

  init(sql: String, binding: PostgresBindings) {
    self.sqlString = sql
    self.bindings = binding
  }

  public func `where`(@ArrayBuilder<SQLWhereItem> _ expr: () -> [SQLWhereItem]) throws -> Self {
    var newSql = self.sqlString
    if !newSql.contains("WHERE") {
      newSql += " WHERE"
    } else {
      newSql += " AND"
    }
    let items = expr()
    var bindings = self.bindings
    var all = [String]()
    for item in items {
      var text = item.description
      if let binds = item.binds {
        for (idx, bind) in binds.enumerated() {
          if let bind {
            try bindings.append(bind)
          } else {
            bindings.appendNull()
          }
          text = text.replacingOccurrences(of: "$\(idx + 1)", with: "$\(bindings.count)")
          all.append(text)
        }
      } else {
        all.append(text)
      }
    }
    newSql += " \(all.joined(separator: " and "))"
    return Query(sql: newSql, binding: bindings)
  }

  public func limit(_ n: Int) -> Query<TYPE> {
    Query(sql: self.sqlString + " LIMIT \(n)", binding: self.bindings)
  }

  public enum OrderBy: String {
    case ascending = "ASC"
    case descending = "DESC"
  }

  public func orderBy(_ columns: ColumnName..., direction: OrderBy = .ascending) -> Self {
    Query(sql: self.sqlString + " ORDER BY \(columns.map(\.description).joined(separator: ",")) \(direction == .descending ? direction.rawValue : "")", binding: self.bindings)
  }

  public func orderBy(_ pairs: (ColumnName, OrderBy)...) -> Self {
    Query(sql: self.sqlString + " ORDER BY \(pairs.map { "\($0.0.description) \($0.1.rawValue)" }.joined(separator: ","))", binding: self.bindings)
  }

  @discardableResult public func execute(transaction: UUID? = nil) async throws -> [TYPE] {
    try await Database.handler.execute(sqlQuery: self, transaction: transaction)
  }

  public var results: QueryResults<TYPE> {
    QueryResults(query: self)
  }
}

extension Query: ExpressibleByStringInterpolation {
  public init(stringInterpolation: StringInterpolation) {
    self.sqlString = stringInterpolation.sql
    self.bindings = stringInterpolation.binds
  }

  public init(stringLiteral value: String) {
    self.sqlString = value
    self.bindings = PostgresBindings()
  }
}

public extension Query {
  struct StringInterpolation: StringInterpolationProtocol {
    public typealias StringLiteralType = String

    @usableFromInline
    var sql: String
    @usableFromInline
    var binds: PostgresBindings

    public init(literalCapacity: Int, interpolationCount: Int) {
      self.sql = ""
      self.binds = PostgresBindings(capacity: interpolationCount)
    }

    public mutating func appendLiteral(_ literal: String) {
      self.sql.append(contentsOf: literal)
    }

    @inlinable
    public mutating func appendInterpolation(_ value: some PostgresThrowingDynamicTypeEncodable) throws {
      try self.binds.append(value, context: .default)
      self.sql.append(contentsOf: "$\(self.binds.count)")
    }

    @inlinable
    public mutating func appendInterpolation(_ value: (some PostgresThrowingDynamicTypeEncodable)?) throws {
      switch value {
      case .none:
        self.binds.appendNull()
      case .some(let value):
        try self.binds.append(value, context: .default)
      }

      self.sql.append(contentsOf: "$\(self.binds.count)")
    }

    @inlinable
    public mutating func appendInterpolation(_ value: some PostgresDynamicTypeEncodable) {
      self.binds.append(value, context: .default)
      self.sql.append(contentsOf: "$\(self.binds.count)")
    }

    @inlinable
    public mutating func appendInterpolation(_ value: (some PostgresDynamicTypeEncodable)?) {
      switch value {
      case .none:
        self.binds.appendNull()
      case .some(let value):
        self.binds.append(value, context: .default)
      }

      self.sql.append(contentsOf: "$\(self.binds.count)")
    }

    @inlinable
    public mutating func appendInterpolation(
      _ value: some PostgresThrowingDynamicTypeEncodable,
      context: PostgresEncodingContext<some PostgresJSONEncoder>
    ) throws {
      try self.binds.append(value, context: context)
      self.sql.append(contentsOf: "$\(self.binds.count)")
    }

    @inlinable
    public mutating func appendInterpolation(unescaped interpolated: String) {
      self.sql.append(contentsOf: interpolated)
    }
  }
}
