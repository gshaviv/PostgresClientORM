//
//  File.swift
//
//
//  Created by Guy Shaviv on 07/01/2024.
//

import Foundation
import PerfectPostgreSQL

public struct DatabaseConnection {
  let connection: PGConnection
  
  init(_ connection: PGConnection) {
    self.connection = connection
  }

  @discardableResult
  public func execute(statement: String, params: [Any?]? = nil) throws -> PGResult {
    do {
      return try connection.execute(statement: statement, params: params)
    } catch {
      throw TableObjectError.general(connection.errorMessage())
    }
  }
}
