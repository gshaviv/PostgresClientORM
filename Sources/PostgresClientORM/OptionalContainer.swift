//
//  OptionalContainer.swift
//
//
//  Created by Guy Shaviv on 24/10/2023.
//

import Foundation

@_documentation(visibility: private)
public class OptionalContainer<Type: Codable> {
  public var value: Type?

  public init() {}
}
