//
//  File.swift
//
//
//  Created by Guy Shaviv on 06/11/2023.
//

import Foundation
import PostgresClientKit

extension PostgresValueConvertible {
  var sqlString: String {
    self is QuoteSQLValue ? "'\(postgresValue)'" : "\(postgresValue)"
  }
}

protocol QuoteSQLValue {}

extension String: QuoteSQLValue {}

extension UUID: PostgresValueConvertible, QuoteSQLValue {
  public var postgresValue: PostgresClientKit.PostgresValue {
    PostgresValue(uuidString)
  }
}

extension Int64: PostgresValueConvertible {
  public var postgresValue: PostgresClientKit.PostgresValue {
    PostgresValue("\(self)")
  }
}

extension NSNull: PostgresValueConvertible {
  public var postgresValue: PostgresValue {
    PostgresValue(nil)
  }
}
