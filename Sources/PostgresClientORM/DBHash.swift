//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation

@propertyWrapper
public class DBHash: Codable {
  public var wrappedValue: Int?

  public init(wrappedValue: Int? = nil) {
    self.wrappedValue = wrappedValue
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.wrappedValue = try? container.decode(Int.self)
  }

  public func encode(to encoder: Encoder) throws {
    if let wrappedValue {
      var container = encoder.singleValueContainer()
      try container.encode(wrappedValue)
    }
  }
}
