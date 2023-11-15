//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresNIO

public struct SQLWhereItem: ExpressibleByStringLiteral, LosslessStringConvertible {
  private var expression: String
  public var description: String { self.expression }
  let binds: [PostgresEncodable?]?

  public init(stringLiteral value: String) {
    self.expression = value
    binds = nil
  }

  public init(_ sql: String) {
    self.expression = sql
    binds = nil
  }

  public init(_ sql: String, variables: [PostgresEncodable?]) {
    self.expression = sql
    self.binds = variables
  }

  public init(_ sql: String, _ variables: PostgresEncodable?...) {
    self.expression = sql
    self.binds = variables
  }
}

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

public func == (lhs: ColumnName, rhs: (some PostgresEncodable)?) -> SQLWhereItem {
  if let rhs {
    return SQLWhereItem("\(lhs) = $1", rhs)
  } else {
    return SQLWhereItem("\(lhs) IS NULL")
  }
}

public func == (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  SQLWhereItem("\(lhs) == \(rhs)")
}

public func < (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) < $1", rhs)
}

public func < (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  SQLWhereItem("\(lhs) < \(rhs)")
}

public func <= (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) <= $1", rhs)
}

public func <= (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  SQLWhereItem("\(lhs) <= \(rhs)")
}

public func > (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) > $1", rhs)
}

public func > (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  SQLWhereItem("\(lhs) > \(rhs)")
}

public func >= (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) >= $1", rhs)
}

public func >= (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  SQLWhereItem("\(lhs) >= \(rhs)")
}

public func != (lhs: ColumnName, rhs: some PostgresEncodable) -> SQLWhereItem {
  SQLWhereItem("\(lhs) <> $1", rhs)
}

public func != (lhs: ColumnName, rhs: ColumnName) -> SQLWhereItem {
  SQLWhereItem("\(lhs) <> \(rhs)")
}

infix operator *=*: MultiplicationPrecedence
infix operator =*: MultiplicationPrecedence
infix operator *=: MultiplicationPrecedence

public func *=* (lhs: ColumnName, rhs: String) -> SQLWhereItem {
  SQLWhereItem("\(lhs) LIKE $1", "%\(rhs)%")
}

public func =* (lhs: ColumnName, rhs: String) -> SQLWhereItem {
  SQLWhereItem("\(lhs) LIKE $1", "\(rhs)%")
}

public func *= (lhs: ColumnName, rhs: String) -> SQLWhereItem {
  SQLWhereItem("\(lhs) LIKE $1", "%\(rhs)")
}

extension Array where Element: PostgresArrayEncodable {
  func contains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem("\(column) IN $1", self)
  }

  func notContains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem("\(column) NOT IN $1", self)
  }
}

extension Query {
  func contains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem(stringLiteral: "\(column) IN (\(self.sqlString))")
  }

  func notContains(_ column: ColumnName) -> SQLWhereItem {
    SQLWhereItem(stringLiteral: "\(column) NOT IN (\(self.sqlString))")
  }
}
