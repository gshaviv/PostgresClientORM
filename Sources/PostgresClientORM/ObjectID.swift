//
//  File.swift
//
//
//  Created by Guy Shaviv on 24/10/2023.
//

import Foundation

@propertyWrapper
public class ID<Value: Codable>: Codable {
  public var wrappedValue: Value?

  public init(wrappedValue: Value? = nil) {
    self.wrappedValue = wrappedValue
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.wrappedValue = try? container.decode(Value.self)
  }

  public func encode(to encoder: Encoder) throws {
    if let wrappedValue {
      var container = encoder.singleValueContainer()
      try container.encode(wrappedValue)
    }
  }
}
