
import Foundation

/// A column name for queries or where clauses.
///
/// A column name can be created from a string, e.g.
/// ```swift
/// let x: ColumnName = "name"
/// ```
/// or
/// ```swift
/// let x = ColumnName("name")
/// ```
/// To create a column name of a ``FieldSubset`` use ``-›`` operator (- and opt-shift-4)
/// ```swift
/// "loc" -› "lat" = 34 // equivalent to column loc_lat
/// ```
public struct ColumnName: LosslessStringConvertible {
  public var name: String
  let fromLiteral: Bool
  public var description: String {
    "\"\(name)\""
  }

  public init(stringLiteral value: String) {
    name = value
    fromLiteral = true
  }

  public init(_ name: String) {
    self.name = name
    fromLiteral = false
  }
}

infix operator -›: MultiplicationPrecedence

/// Column name of a column in a ``FieldSubset`` property
public func -› (lhs: ColumnName, rhs: ColumnName) -> ColumnName {
  if rhs.name.isEmpty {
    lhs
  } else {
    ColumnName("\(lhs.name)_\(rhs.name)")
  }
}
