//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresNIO

/// An SQL where clause
///
/// Describes a condition in an SQL query where term
public struct SQLWhereItem: ExpressibleByStringLiteral, LosslessStringConvertible {
  private var expression: String
  public var description: String { self.expression }
  let binds: [PostgresEncodable?]?

  /// init with a string literal
  /// - Parameter sql: The SQL string for the clause, e.g. name = "New"
  public init(stringLiteral value: String) {
    self.expression = value
    self.binds = nil
  }
  
  /// init with a string literal
  /// - Parameter sql: The SQL string for the clause, e.g. name = "New"
  public init(_ sql: String) {
    self.expression = sql
    self.binds = nil
  }

  @_documentation(visibility: private)
  public init(_ sql: String, variables: [PostgresEncodable?]) {
    self.expression = sql
    self.binds = variables
  }
  
  /// Init with an SQL test and variables to bind
  /// - Parameters:
  ///   - sql: The SQL statement with references to variable bindings
  ///   - variables: The variables to bind
  ///
  ///   Example:
  ///   ```swift
  ///   SQLWhereItem("name = $1", myName)
  ///   ```
  public init(_ sql: String, _ variables: PostgresEncodable?...) {
    self.expression = sql
    self.binds = variables
  }
}

/// Group where conditions with an OR operator
/// - Parameter _: a DSL block with the conditions
/// - Returns: A where item containing the OR'ed experessions
///
/// Example:
/// ```swift
/// .where {
///       Or {
///       "name" = "Joe"
///       "name" = "Jane"
///       }
/// }
/// ```
public func Or(@ArrayBuilder<SQLWhereItem> _ conditions: () -> [SQLWhereItem]) -> SQLWhereItem {
  var bindings = [PostgresEncodable?]()
  var all = [String]()
  for item in conditions() {
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

  return SQLWhereItem("(\(all.joined(separator: " OR ")))", variables: bindings)
}

/// Group where conditions with an AND operator
/// - Parameter _: a DSL block with the conditions
/// - Returns: A where item containing the AND'ed experessions
public func And(@ArrayBuilder<SQLWhereItem> _ conditions: () -> [SQLWhereItem]) -> SQLWhereItem {
  var bindings = [PostgresEncodable?]()
  var all = [String]()
  for item in conditions() {
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

  return SQLWhereItem("(\(all.joined(separator: " AND ")))", variables: bindings)
}

/// A where item comparing a column to an expression
/// - Parameters:
///   - lhs: name of column
///   - rhs: expression
/// - Returns: SQLWhereItem
public func == (lhs: ColumnName, rhs: (some PostgresEncodable)?) -> SQLWhereItem {
  if let rhs {
    return SQLWhereItem("\(lhs) = $1", rhs)
  } else {
    return SQLWhereItem("\(lhs) IS NULL")
  }
}

/// A where item comparing one column to another
/// - Parameters:
///   - lhs: Colum name
///   - rhs: Column name
/// - Returns: SQLWhereitem
public func == (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  if rhs.fromLiteral {
    return lhs == rhs.description
  } else {
    return SQLWhereItem("\(lhs) == \(rhs)")
  }
}

public func < (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) < $1", rhs)
}

public func < (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  if rhs.fromLiteral {
    return lhs < rhs.description
  } else {
    return SQLWhereItem("\(lhs) < \(rhs)")
  }
}

public func <= (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) <= $1", rhs)
}

public func <= (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  if rhs.fromLiteral {
    return lhs <= rhs.description
  } else {
    return SQLWhereItem("\(lhs) <= \(rhs)")
  }
}

public func > (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) > $1", rhs)
}

public func > (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  if rhs.fromLiteral {
    return lhs > rhs.description
  } else {
    return SQLWhereItem("\(lhs) > \(rhs)")
  }
}

public func >= (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) >= $1", rhs)
}

public func >= (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  if rhs.fromLiteral {
    return lhs >= rhs.description
  } else {
    return SQLWhereItem("\(lhs) >= \(rhs)")
  }
}

public func != (lhs: ColumnName, rhs: (some PostgresEncodable)?) -> SQLWhereItem {
  if let rhs {
    return SQLWhereItem("\(lhs) <> $1", rhs)
  } else {
    return SQLWhereItem("\(lhs) IS NOT NULL")
  }
}

public func != (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  if rhs.fromLiteral {
    return rhs != lhs.description
  } else {
    return SQLWhereItem("\(lhs) <> \(rhs)")
  }
}

infix operator %=%: MultiplicationPrecedence
infix operator =%: MultiplicationPrecedence
infix operator %=: MultiplicationPrecedence

/// A where item using LIKE
/// - Parameters:
///   - lhs: column name
///   - rhs: The constant in the LIKE expression
/// - Returns: lhs like '%rhs%'
public func %=% (lhs: ColumnName, rhs: String) -> SQLWhereItem {
  SQLWhereItem("\(lhs) LIKE $1", "%\(rhs)%")
}

/// A where item using LIKE
/// - Parameters:
///   - lhs: column name
///   - rhs: The constant in the LIKE expression
/// - Returns: lhs like 'rhs%'
public func =% (lhs: ColumnName, rhs: String) -> SQLWhereItem {
  SQLWhereItem("\(lhs) LIKE $1", "\(rhs)%")
}
/// A where item using LIKE
/// - Parameters:
///   - lhs: column name
///   - rhs: The constant in the LIKE expression
/// - Returns: lhs like '%rhs'
public func %= (lhs: ColumnName, rhs: String) -> SQLWhereItem {
  SQLWhereItem("\(lhs) LIKE $1", "%\(rhs)")
}

public extension Array where Element: PostgresArrayEncodable {
  /// Where item for IN
  /// - Parameter column: column name
  /// - Returns: "column in (self)"
  func contains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem("\(column) IN $1", self)
  }

  /// Where item for NOT  IN
  /// - Parameter column: column name
  /// - Returns: "column not in (self)"
  func notContains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem("\(column) NOT IN $1", self)
  }
}

public extension Query {
  /// column is in results of another query
  func contains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem(stringLiteral: "\(column) IN (\(self.sqlString))")
  }

  /// column is not in results of another query
  func notContains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem(stringLiteral: "\(column) NOT IN (\(self.sqlString))")
  }
}
