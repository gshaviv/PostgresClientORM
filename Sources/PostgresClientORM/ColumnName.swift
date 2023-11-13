//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation

public struct ColumnName: ExpressibleByStringLiteral, LosslessStringConvertible {
  public var name: String
  public var description: String {
    CharacterSet.lowercaseLetters.isSuperset(of: CharacterSet(charactersIn: name)) ? name : "\"\(name)\""
  }
  
  public init(stringLiteral value: String) {
    name = value
  }

  public init(_ name: String) {
    self.name = name
  }
}

infix operator -›: MultiplicationPrecedence

public func -› (lhs: ColumnName, rhs: ColumnName) -> ColumnName {
  ColumnName("\(lhs)_\(rhs)")
}
