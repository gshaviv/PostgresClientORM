//
//  File.swift
//  
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresClientKit

actor ConnectionGroup {
  static var shared = ConnectionGroup()
  var pending = 0

  private static var configuration: PostgresClientKit.ConnectionConfiguration {
    var configuration = PostgresClientKit.ConnectionConfiguration()
    if let url = ProcessInfo.processInfo.environment["DATABASE_URL"] {
      configuration.set(url: url)
    } else {
      configuration.host = ProcessInfo.processInfo.environment["DATABASE_HOST"] ?? "localhost" // "host.docker.internal"
      configuration.database =  ProcessInfo.processInfo.environment["DATABASE_NAME"] ?? "db"
      configuration.user =  ProcessInfo.processInfo.environment["DATABASE_USER"] ?? "user"
      configuration.credential = .scramSHA256(password:  ProcessInfo.processInfo.environment["DATABASE_PASSWROD"] ?? "shh...")
      configuration.ssl = Bool( ProcessInfo.processInfo.environment["DATABASE_SSL"] ?? "false") ?? false
      configuration.port = Int( ProcessInfo.processInfo.environment["DATABASE_PORT"] ?? "5432") ?? 5432
    }
    return configuration
  }

  var group: [Connection] = []

  func obtain() throws -> Connection {
    if group.isEmpty {
      guard pending < 24 else {
        throw TableObjectError.general("Too Many pending connections")
      }
      let connection = try PostgresClientKit.Connection(configuration: Self.configuration)
      pending += 1
      return connection
    } else {
      pending += 1
      return group.removeLast()
    }
  }

  private func finished(connection: Connection) {
    group.append(connection)
    pending -= 1
  }

  nonisolated func release(connection: Connection) {
    Task {
      await finished(connection: connection)
    }
  }

  func withConnection(doBlock: (Connection) async throws -> Void) async throws {
    let connection = try obtain()
    do {
      try await doBlock(connection)
      finished(connection: connection)
    } catch {
      finished(connection: connection)
      throw error
    }
  }
}
