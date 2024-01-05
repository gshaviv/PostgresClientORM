import Foundation
public enum KeyType {
    case camelCase
    case snakeCase
}

public enum CodingKeyType {
    case camelCase
    case snakeCase
    case none
}

/// Expans to conformnce to the ``FieldSubset`` protocol
@attached(member, names: named(Columns), named(init(row:)), named(encode(row:)))
@attached(extension, conformances: FieldSubset)
public macro Columns(_ type: KeyType = .snakeCase) = #externalMacro(module: "PostgresORMMacros", type: "CodingKeysMacro")

/// Make the clas a ``TableObject`` so it can be stored and/or read from a postgres table
/// - Parameters:
///     - columns: default column name generation, .snakeCase or .camlCase, default is snakeCase
///     - table: name of table
///     - idType: type of id property to generate
///     - idName: name of Id column if not "id"
///     - trackDirty: track if the object was modifierd after reading and implmenet the ``TrackingDirty/save(transaction:)`` method on the instance so it can be conditional updated or inserted.
///     - codable: if .snakeCase or .camelCase will generate Codable implementation using the spacified value for the CodingKeys
@attached(member, names: named(CodingKeys), named(init(from:)), named(encode(to:)), named(idColumn), named(id), named(Columns), named(_idHolder), named(dbHash), named(_dbHash), named(init(row:)), named(encode(row:)), named(tableName))
@attached(extension, conformances: TableObject, Codable, TrackingDirty, FieldSubset)
public macro TableObject(columns: KeyType = .snakeCase, table: String, idType: Any.Type = UUID.self, idName: String = "id", trackDirty: Bool = true, codable: CodingKeyType = .none) = #externalMacro(module: "PostgresORMMacros", type: "TablePersistMacro")

/// Set a custom name for the column holding the property
/// Example:
/// ```swift
/// @Column(name: "last_name" var name: String
/// ```
@attached(peer)
public macro Column(name: String) = #externalMacro(
    module: "PostgresORMMacros",
    type: "CustomCodingKeyMacro"
)

/// Set a custom name for ``Codable``
/// Example:
/// ```swift
/// @Coding(key: "entityID" var id: UUID
/// ```
@attached(peer)
public macro Coding(key: String) = #externalMacro(
    module: "PostgresORMMacros",
    type: "CustomCodingKeyMacro"
)

/// Ignore this column and do not encode/decode it from an SQL row
@attached(peer)
public macro ColumnIgnored() = #externalMacro(module: "PostgresORMMacros", type: "CodingKeyIgnoredMacro")

/// Ignore this property when generating `CodingKeys`
@attached(peer)
public macro CodingKeysIgnored() = #externalMacro(module: "PostgresORMMacros", type: "CodingKeyIgnoredMacro")
