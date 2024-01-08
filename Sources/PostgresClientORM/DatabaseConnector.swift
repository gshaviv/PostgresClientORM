//
//  ConnectionGroup.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PerfectPostgreSQL

/// A connection group.
///
/// For multi threaded access you would need a connectin per thread. The ``ConnectionGroup`` lets you obtain a connection, use it, and return it when done. No need to directly access this class  as ``Database.handler`` already accesses it for you.
///
/// The ``ConnectionGroup`` configures the connection based on the environment variables. It will first try to see if the variable **DATABASE_URL** is defined and if so will use it. It will use an ssl connection unless the URL includes the option `?sslmode=disable`. Next
/// it will use the environemnt variables:
///
/// **DATABASE_HOST**
///
/// **DATABASE_PORT** -> default 5432
///
/// **DATABASE_USER**
///
/// **DATABASE_NAME**
///
/// **DATABASE_SSL** (use ssl if this enviroment variable evaluates to TRUE.
public enum DatabaseConnector {
  private static var configuration: String {
    if let url = ProcessInfo.processInfo.environment["DATABASE_URL"] {
      return url
    } else {
      var elements = [String]()
      let env = [
        ("DATABASE_HOST", "host"),
        ("DATABASE_PORT", "port"),
        ("DATABASE_USER", "user"),
        ("DATABASE_PASSWROD", "password"),
        ("DATABASE_NAME", "dbname"),
        ("DATABASE_SSL", "sslmode"),
      ]
      for option in env {
        if let v = ProcessInfo.processInfo.environment[option.0] {
          elements.append("\(option.1)=\(v)")
        }
      }
      return elements.joined(separator: " ")
    }
  }

  /// Obtain a new or existing and available connection
  /// - Returns: PostgresConnection
  static func connect() throws -> DatabaseConnection {
      let connection = PGConnection()
      let status = connection.connectdb(Self.configuration)
      guard status == .ok else {
        throw TableObjectError.general("Bad connection status: \(status)")
      }
      return DatabaseConnection(connection)
  }

  /// Get a connection for a block
  ///
  /// The connection is release when the block terminates. This is equivalent to doing ``obtain()`` and ``release(:)`` around the block.
  ///
  /// - Parameter doBlock: The block that is passed the connection.
  static func withConnection<T>(doBlock: (DatabaseConnection) async throws -> T) async throws -> T {
    let connection = try connect()
    do {
      return try await doBlock(connection)
    } catch {
      throw error
    }
  }
}
