//
//  Query.swift
//
//
//  Created by Guy Shaviv on 23/10/2023.
//

import Foundation
import PerfectPostgreSQL

/// A query for a ``FieldSubset`` type
///
/// You don't create a Query directly rather via one of the ``TableObject`` methods: ``select()``, ``delete()`` or ``update()``
public struct Query<TYPE: FieldSubset> {
    let sqlString: String
    let bindings: [Any?]

    init(_ sql: String, _ variables: Any?...) throws {
        sqlString = sql
        bindings = variables
    }

    init(sql: String, variables: [Any?]) throws {
        sqlString = sql
        bindings = variables
    }

    init(sql: String) {
        sqlString = sql
        bindings = []
    }

    init(sql: String, binding: [Any?]) {
        sqlString = sql
        bindings = binding
    }

    /// Add *WHERE* caluses to the query
    ///
    /// - Example:
    ///  ```swift
    ///  Planet.select().where {
    ///      Planet.column(.name) = "Earth"
    ///  }
    ///  ```
    ///
    /// - Parameter _: a DSL block containaing where conditions.
    /// - Returns: a Query with the where items applied.
    public func `where`(@ArrayBuilder<SQLWhereItem> _ expr: () -> [SQLWhereItem]) throws -> Self {
        var newSql = sqlString
        if !newSql.contains("WHERE") {
            newSql += " WHERE"
        } else {
            newSql += " AND"
        }
        let items = expr()
        var bindings = bindings
        var all = [String]()
        for item in items {
            var text = item.description
            if let binds = item.binds {
                for (idx, bind) in binds.enumerated() {
                    bindings.append(bind)
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

    /// SQL limit
    /// - Parameter n: number of results to limit
    /// - Returns: the query with limit applied
    public func limit(_ n: Int) -> Query<TYPE> {
        Query(sql: sqlString + " LIMIT \(n)", binding: bindings)
    }

    /// Returrn a column value on modified rows
    /// - Note: This must be the last clause in the statement
    /// - Parameter col: column name
    /// - Returns: Query with returning clause
    public func returning(_ col: ColumnName) -> Query<TYPE> {
        Query(sql: sqlString + " RETURNING \(col)", binding: bindings)
    }

    /// Sort direction
    public enum OrderBy: String {
        /// sort direction ascending
        case ascending = "ASC"
        /// sort direction descendng
        case descending = "DESC"
    }

    /// Order by (sort) the results
    /// - Parameters:
    ///   - columns: the column names to sort by
    ///   - direction: The direction of the sort, default = .ascending
    /// - Returns: Query with ordering applied
    public func orderBy(_ columns: ColumnName..., direction: OrderBy = .ascending) -> Self {
        Query(sql: sqlString + " ORDER BY \(columns.map(\.description).joined(separator: ",")) \(direction == .descending ? direction.rawValue : "")", binding: bindings)
    }

    /// Order by
    /// - Parameter pairs: paris of column names with sort direction, use this version if sort needs to be by different direction each column
    /// - Returns: Query with order applied
    public func orderBy(_ pairs: (ColumnName, OrderBy)...) -> Self {
        Query(sql: sqlString + " ORDER BY \(pairs.map { "\($0.0.description) \($0.1.rawValue)" }.joined(separator: ","))", binding: bindings)
    }

    /// Execute query
    /// - Parameter transactionConnection: if part of a transaction
    /// - Returns: an array of results
    @discardableResult public func execute(transactionConnection: PGConnection? = nil) async throws -> [TYPE] {
        try await Database.handler.execute(sqlQuery: self, transactionConnection: transactionConnection)
    }

    /// Sequence of results
    ///
    /// This is more optimal than loading all the results to memory in an array. Returns a sequence of results that can be iterated on.
    ///
    /// - Example:
    ///
    /// ```swift
    /// for try await item in query.results {
    ///    // Do something with item ...
    ///  }
    ///  ```
    public var results: QueryResults<TYPE> {
        QueryResults(query: self)
    }

    public func results(transactionConnection: PGConnection) -> QueryResults<TYPE> {
        QueryResults(query: self, connection: transactionConnection)
    }
}

extension Query: ExpressibleByStringInterpolation {
    public init(stringInterpolation: StringInterpolation) {
        sqlString = stringInterpolation.sql
        bindings = stringInterpolation.binds
    }

    public init(stringLiteral value: String) {
        sqlString = value
        bindings = []
    }
}

public extension Query {
    struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        @usableFromInline
        var sql: String
        @usableFromInline
        var binds: [Any?]

        public init(literalCapacity _: Int, interpolationCount: Int) {
            sql = ""
            binds = []
            binds.reserveCapacity(interpolationCount)
        }

        public mutating func appendLiteral(_ literal: String) {
            sql.append(contentsOf: literal)
        }

        @inlinable
        public mutating func appendInterpolation(_ value: Any?) {
            binds.append(value)
            sql.append(contentsOf: "$\(binds.count)")
        }

        @inlinable
        public mutating func appendInterpolation(_ value: (some Codable)?) throws {
            if let value {
                let enc = JSONEncoder()
                let data = try enc.encode(value)
                if let str = String(data: data, encoding: .utf8) {
                    binds.append(str)
                } else {
                    binds.append("{}")
                }
            } else {
                binds.append(value)
            }

            sql.append(contentsOf: "$\(binds.count)")
        }

        @inlinable
        public mutating func appendInterpolation(unescaped interpolated: String) {
            sql.append(contentsOf: interpolated)
        }
    }
}
