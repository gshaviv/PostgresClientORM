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
actor ConnectionGroup {
    static var shared = ConnectionGroup()

    private init() {}

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

    var all: [PGConnection] = []
    var available: [PGConnection] = []

    /// Obtain a new or existing and available connection
    /// - Returns: PostgresConnection
    func obtain() throws -> PGConnection {
        if available.isEmpty {
            guard all.count < 24 else {
                throw TableObjectError.general("Too Many pending connections")
            }
            let connection = PGConnection()
            let status = connection.connectdb(Self.configuration)
            guard status == .ok else {
                throw TableObjectError.general("Bad connection status: \(status)")
            }
            all.append(connection)
            return connection
        } else {
            let outgoing = available.removeLast()
            return outgoing
        }
    }

    private func finished(connection: PGConnection) {
        available.append(connection)
    }

    /// Releae a previously obtained connection. No more actions can be performed on this connection.
    /// - Parameter connection: The connection to release
    nonisolated func release(connection: PGConnection) {
        Task.detached {
            await self.finished(connection: connection)
        }
    }

    /// Get a connection for a block
    ///
    /// The connection is release when the block terminates. This is equivalent to doing ``obtain()`` and ``release(:)`` around the block.
    ///
    /// - Parameter doBlock: The block that is passed the connection.
    func withConnection(doBlock: (PGConnection) async throws -> Void) async throws {
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
