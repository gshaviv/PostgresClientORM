//
//  File.swift
//
//
//  Created by Guy Shaviv on 24/10/2023.
//

import Foundation

class IDHolder<Type: Codable>: Codable {
  var value: Type?
  
  init() {}
  
  required init(from decoder: Decoder) throws {
//    let container = try decoder.singleValueContainer()
//    value = try container.decode(Type.self)
  }
  
  func encode(to encoder: Encoder) throws {
//    var container = encoder.singleValueContainer()
//    try container.encode(value)
  }
}
