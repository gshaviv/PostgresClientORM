//
//  ArrayBuilder.swift
//  MrT
//
//  Created by Guy Shaviv on 23/07/2023.
//

import Foundation

@resultBuilder
public enum ArrayBuilder<T> {
  public static func buildEither(first component: [T]) -> [T] {
    component
  }

  public static func buildEither(second component: [T]) -> [T] {
    component
  }

  public static func buildOptional(_ component: [T]?) -> [T] {
    component ?? []
  }

  public static func buildBlock(_ components: [T]...) -> [T] {
    components.flatMap { $0 }
  }

  public static func buildExpression(_ expression: T) -> [T] {
    [expression]
  }

  public static func buildExpression(_ expression: Void) -> [T] {
    []
  }

  public static func buildArray(_ components: [[T]]) -> [T] {
    components.flatMap { $0 }
  }
}

precedencegroup DictionaryAssignment {
  lowerThan: ComparisonPrecedence
}

infix operator =>: DictionaryAssignment

public func => <T>(lhs: String, rhs: T) -> (String, T) {
  (lhs, rhs)
}

@resultBuilder
public enum DictionaryBuilder<T> {
  public static func buildExpression(_ expression: (String, T)) -> [String: T] {
    [expression.0: expression.1]
  }

  public static func buildExpression(_ expression: (String, T?)) -> [String: T] {
    if let value = expression.1 {
      return [expression.0: value]
    } else {
      return [:]
    }
  }

  public static func buildBlock(_ components: [String: T]...) -> [String: T] {
    var result = [String: T]()
    for component in components {
      result = result.merging(component, uniquingKeysWith: { $1 })
    }
    return result
  }

  public static func buildOptional(_ component: [String: T]?) -> [String: T] {
    component ?? [:]
  }

  public static func buildEither(first component: [String: T]) -> [String: T] {
    component
  }

  public static func buildEither(second component: [String: T]) -> [String: T] {
    component
  }

  public static func buildArray(_ components: [[String: T]]) -> [String: T] {
    var result = [String: T]()
    for component in components {
      result = result.merging(component, uniquingKeysWith: { $1 })
    }
    return result
  }
}
