//
//  File.swift
//  
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import PostgresNIO
import Logging

public enum PostgresClientORM {
  public static var logger: Logger?
  
  internal static var useLogger: Logger {
    if let logger {
      return logger
    } else {
      let newLogger = Logger(label: "Postgres")
      logger = newLogger
      return newLogger
    }
  }
}

actor ConnectionGroup {
  static var shared = ConnectionGroup()
  
  private init() {}

  private static var configuration: PostgresConnection.Configuration {
    get throws {
      if let url = ProcessInfo.processInfo.environment["DATABASE_URL"] {
        return try PostgresConnection.Configuration(url: url)
      } else {
        return PostgresConnection.Configuration(host: ProcessInfo.processInfo.environment["DATABASE_HOST"] ?? "localhost" /* "host.docker.internal"*/,
                                                port: Int( ProcessInfo.processInfo.environment["DATABASE_PORT"] ?? "5432") ?? 5432,
                                                username: ProcessInfo.processInfo.environment["DATABASE_USER"] ?? "user",
                                                password: ProcessInfo.processInfo.environment["DATABASE_PASSWROD"] ?? "shh...",
                                                database: ProcessInfo.processInfo.environment["DATABASE_NAME"] ?? "db",
                                                tls: Bool( ProcessInfo.processInfo.environment["DATABASE_SSL"] ?? "false") ?? false ? .require(try NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration())) : .disable)
      }
    }
  }

  var group: [PostgresConnection] = []
  var inUse: [Int: PostgresConnection] = [:]

  func obtain() async throws -> PostgresConnection {
    if group.isEmpty {
      guard group.count + inUse.count < 24 else {
        throw TableObjectError.general("Too Many pending connections")
      }
      let id = group.count + inUse.count
      let connection = try await PostgresConnection.connect(configuration: Self.configuration, id: id, logger: PostgresClientORM.useLogger)
      inUse[id] = connection
      return connection
    } else {
      let outgoing = group.removeLast()
      inUse[outgoing.id] = outgoing
      return outgoing
    }
  }

  private func finished(connection: PostgresConnection) {
    group.append(connection)
    inUse[connection.id] = nil
  }

  nonisolated func release(connection: PostgresConnection) {
    Task {
      await finished(connection: connection)
    }
  }

  func withConnection(doBlock: (PostgresConnection) async throws -> Void) async throws {
    let connection = try await obtain()
    do {
      try await doBlock(connection)
      finished(connection: connection)
    } catch {
      finished(connection: connection)
      throw error
    }
  }
}

extension PostgresConnection.Configuration {
  init(url: String) throws {
    guard let components = URLComponents(string: url) else {
      throw TableObjectError.general("Bad URL \(url)")
    }
    guard let host = components.host else {
      throw TableObjectError.general("no host in \(url)")
    }
    guard let db = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).components(separatedBy: "/").first else {
      throw TableObjectError.general("No db in \(url)")
    }
    guard let user = components.user else {
      throw TableObjectError.general("No useer in \(url)")
    }
    guard let password = components.password else {
      throw TableObjectError.general("No passwod in \(url)")
    }
    let ssl: TLS
    if components.queryItems?.filter({ $0.name.lowercased() == "sslmode" }).first?.value == "disable" {
      ssl = .disable
    } else {
      ssl = .require(try NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration()))
    }
    let port = components.port ?? 5432
    self.init(host: host, port: port, username: user, password: password, database: db, tls: ssl)
  }
}
