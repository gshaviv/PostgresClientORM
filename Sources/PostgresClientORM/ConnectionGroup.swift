//
//  File.swift
//
//
//  Created by Guy Shaviv on 30/10/2023.
//

import Foundation
import Logging
import PostgresNIO

public enum PostgresClientORM {
  public static var logger: Logger = .init(label: "Postgres")
  public static var eventLoop = PostgresConnection.defaultEventLoopGroup.any()
  
  /// Configure a PostgresClientORM
  ///
  /// - Parameters:
  ///   - logger: The logger to use (default, creates a dedicated logger)
  ///   - eventLoop: The event loop to use (default creates a dedicated loop)
  ///
  /// If used in a capor app, in the configure method do:
  /// ```swift
  /// PostgresClientORM.configure(eventLoop: app.eventLoopGroup.next())
  ///
  /// ```
  public static func configure(logger: Logger = Logger(label: "Postgres"), eventLoop: EventLoop = PostgresConnection.defaultEventLoopGroup.any()) {
    Self.logger = logger
    Self.eventLoop = eventLoop
  }
}

/// A connection group.
///
/// For multi threaded access you would need a connectin per thread. The ``ConnectionGroup`` lets you obtain a connection, use it, and return it when done. No need to directly access this class unless doing transaction as ``Database.handler`` already accesses it for you.
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
actor ConnectionGroup {
  static var shared = ConnectionGroup()

  private init() {}

  private static var configuration: PostgresConnection.Configuration {
    get throws {
      if let url = ProcessInfo.processInfo.environment["DATABASE_URL"] {
        return try PostgresConnection.Configuration(url: url)
      } else {
        return try PostgresConnection.Configuration(host: ProcessInfo.processInfo.environment["DATABASE_HOST"] ?? "localhost" /* "host.docker.internal"*/,
                                                    port: Int(ProcessInfo.processInfo.environment["DATABASE_PORT"] ?? "5432") ?? 5432,
                                                    username: ProcessInfo.processInfo.environment["DATABASE_USER"] ?? "user",
                                                    password: ProcessInfo.processInfo.environment["DATABASE_PASSWROD"] ?? "shh...",
                                                    database: ProcessInfo.processInfo.environment["DATABASE_NAME"] ?? "db",
                                                    tls: Bool(ProcessInfo.processInfo.environment["DATABASE_SSL"] ?? "false") ?? false ? .require(NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration())) : .disable)
      }
    }
  }

  var all: [PostgresConnection] = []
  var available: [PostgresConnection] = []
  
  /// Obtain a new or existing and available connection
  /// - Returns: PostgresConnection
  func obtain() async throws -> PostgresConnection {
    if available.isEmpty {
      guard all.count < 24 else {
        throw TableObjectError.general("Too Many pending connections")
      }
      let connection = try await PostgresConnection.connect(configuration: Self.configuration, id: all.count + 1, logger: PostgresClientORM.logger)
      all.append(connection)
      return connection
    } else {
      let outgoing = available.removeLast()
      return outgoing
    }
  }

  private func finished(connection: PostgresConnection) {
    available.append(connection)
  }
  
  /// Releae a previously obtained connection. No more actions can be performed on this connection.
  /// - Parameter connection: The connection to release
  nonisolated func release(connection: PostgresConnection) {
    Task.detached {
      await self.finished(connection: connection)
    }
  }
  
  /// Get a connection for a block
  ///
  /// The connection is release when the block terminates. This is equivalent to doing ``obtain()`` and ``release(:)`` around the block.
  ///
  /// - Parameter doBlock: The block that is passed the connection.
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
      ssl = try .require(NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration()))
    }
    let port = components.port ?? 5432
    self.init(host: host, port: port, username: user, password: password, database: db, tls: ssl)
  }
}
