//
//  Children.swift
//
//
//  Created by Guy Shaviv on 31/10/2023.
//

import Foundation
import PerfectPostgreSQL

/// A property that is a one-to-many relation
///
/// Setup the relationship on the parent side (the one in the relation) specifying the type of the children (must be``TableObject`` convorming), the column name in the child type, and optionally specify a sorting order for the children
/// This relation doesn't add any column to the parent, only to the child.
///
/// ```swift
///  let planets = Children(ofType: Planet.self, by: .star, sortBy: Planet.column(,name), order: .ascending) // the sortBy and order arguments are optional
///  ```
///
///  You need to first load the children before attempting to access them, e.g.:
///  ```swift
///  try await star.loadChildren(\.planets)
///  ```
///  and you can then access the values by one of:
///  ```swift
///  for planet in planets {
///  ...
///  }
///  ```
///  or
///  ```swift
///  let thePlantes = planets.values
///  ```
///  or
///  ```swift
///  for idx in 0 ..< planets.count {
///         let aPlanet = planets[idx]
///                    ...
///   }
///   ```
public class Children<Child: TableObject>: Sequence, Codable {
  public typealias AsyncIterator = Children<Child>
  public typealias Element = Child
  /// The column on the child that is referencing self
  public let referencingColumn: Child.Columns
  /// The [Child] array that was loaded, nil if not loaded yet
  public private(set) var loadedValues: [Child]?
  let sortKey: ColumnName?
  let sortDir: Query<Child>.OrderBy

  /// Init a one-to-many relationship
  /// - Parameters:
  ///   - childType: The type of the child
  ///   - childCol: The column in the child that references self (with value equql self.id)
  ///   - sortBy: Optional - sort order for the children
  ///   - order: Optional: sort direction for the children, i.e. .ascending or .descending (default = .ascending)
  public init(ofType _: Child.Type, by childCol: Child.Columns, sortBy: ColumnName? = nil, order: Query<Child>.OrderBy = .ascending) {
    referencingColumn = childCol
    sortKey = sortBy
    sortDir = order
  }

  public required init(from _: Decoder) throws {
    throw TableObjectError.general("Can't decode chiclren")
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    guard let values = values as? any Encodable else {
      throw TableObjectError.general("Children type must be encodable")
    }
    try container.encode(values)
  }

  /// The values (objects) loaded or an empty array if not loaded yet
  public var values: [Child] {
    loadedValues ?? []
  }

  /// Has the values been loaded yet?
  public var isLoaded: Bool {
    loadedValues != nil
  }

  public subscript(idx: Int) -> Child {
    values[idx]
  }

  /// load the children
  /// - Parameters:
  ///   - parentId: The id of the parent (self)
  ///   - connection: if participating in a transaction
  ///
  ///   - See Also:
  ///    ``TableObect.loadChildren(_:)``
  public func load(parentId: any LosslessStringConvertible, connection: DatabaseConnection? = nil) async throws {
    var query = try Child.select()
      .where {
        Child.column(self.referencingColumn) == parentId
      }

    if let sortKey {
      query = query.orderBy(sortKey, direction: sortDir)
    }

    loadedValues = try await query
      .execute(connection: connection)
  }

  /// The number of objects loaded, or zero if not loaded yet
  public var count: Int { values.count }

  /// Unload all objects, need to be followed by a load before accessing again the values
  public func reset() {
    loadedValues = nil
  }

  /// Reload children
  /// - Parameter parentId: id of self
  public func reload(parentId: any LosslessStringConvertible) async throws {
    reset()
    try await load(parentId: parentId)
  }

  public func makeIterator() -> Array<Child>.Iterator {
    values.makeIterator()
  }
}

/// A x-to-one rlation
///
/// if the other end of the relation has a ``Children`` property this is a one-to-many relation. A Parent cannot be optional, i.e. it must have an id. For types that have an optional parent, set the parent itself to be optional, e.g.
/// ```swift
/// let p: Parent<Planet>?
/// ```
public class Parent<DAD: TableObject>: Codable, FieldSubset {
  public private(set) var id: DAD.IDType
  public private(set) var value: DAD?

  public init(_ id: DAD.IDType) {
    self.id = id
    value = nil
  }

  public init(_ value: DAD) throws {
    self.value = value
    if let id = value.id {
      self.id = id
    } else {
      throw TableObjectError.general("parent Id == nil")
    }
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    id = try container.decode(DAD.IDType.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(id)
  }

  public var type: DAD.Type { DAD.self }

  /// Load the parent object
  ///
  /// Fetches the parent from the database.
  ///
  /// - Note: If the parent is already loaded in memory, this will not create a reference to it, but load another copy of it.
  ///
  /// - Parameter connection: if part of a transaction
  /// - Returns: the parent object
  @discardableResult public func get(connection: DatabaseConnection? = nil) async throws -> DAD {
    if let value {
      return value
    }
    value = try await DAD.fetch(id: id, connection: connection)
    guard let value else {
      throw TableObjectError.general("Missing parent of type \(type)")
    }
    return value
  }

  public enum Columns: String, CodingKey {
    case root = ""
  }

  public required init(row: RowDecoder<Columns>) throws {
    id = try row.decode(DAD.IDType.self, forKey: .root)
  }

  public func encode(row: RowEncoder<Columns>) throws {
    try row.encode(id, forKey: .root)
  }
}

public extension TableObject {
  /// load children
  /// - Parameters:
  ///   - keypath: keypath of property of type ``Children``
  ///   - transaction: id of transaction if in a transaction
  /// - Returns: the objects loaded, equal to va;ues
  @discardableResult func loadChildren<ChildType>(_ keypath: KeyPath<Self, Children<ChildType>>, connection: DatabaseConnection? = nil) async throws -> [ChildType] {
    guard let id else {
      throw TableObjectError.general("id is nil")
    }
    try await self[keyPath: keypath].load(parentId: id, connection: connection)
    return self[keyPath: keypath].values
  }
}
