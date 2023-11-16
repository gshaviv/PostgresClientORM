import PostgresNIO

public enum KeyType {
  case camelCase
  case snakeCase
}

public enum CodingKeyType {
  case camelCase
  case snakeCase
  case none
}

@attached(member, names: named(Columns), named(init(row:)), named(encode(row:)))
@attached(extension, conformances: FieldSubset)
public macro Columns(_ type: KeyType = .snakeCase) = #externalMacro(module: "PostgresORMMacros", type: "CodingKeysMacro")

@attached(member, names: named(CodingKeys), named(init(from:)), named(encode(to:)), named(idColumn), named(id), named(Columns), named(_idHolder), named(dbHash), named(_dbHash), named(init(row:)), named(encode(row:)), named(tableName))
@attached(extension, conformances: TableObject, Codable, TrackingDirty, FieldSubset)
public macro TableObject(columns: KeyType = .snakeCase, table: String, idType: Any.Type, idName: String = "id", trackDirty: Bool = true, codable: CodingKeyType = .none) = #externalMacro(module: "PostgresORMMacros", type: "TablePersistMacro")

@attached(peer)
public macro Column(name: String) = #externalMacro(
  module: "PostgresORMMacros",
  type: "CustomCodingKeyMacro"
)

@attached(peer)
public macro Coding(key: String) = #externalMacro(
  module: "PostgresORMMacros",
  type: "CustomCodingKeyMacro"
)

@attached(peer)
public macro ColumnIgnored() = #externalMacro(module: "PostgresORMMacros", type: "CodingKeyIgnoredMacro")

@attached(peer)
public macro CodingKeysIgnored() = #externalMacro(module: "PostgresORMMacros", type: "CodingKeyIgnoredMacro")

@attached(extension,
          names:
          named(psqlType),
          named(psqlFormat),
          named(encode(info:context:)),
          named(init(from:type:format:context:)),
          conformances:
          PostgresCodable)
public macro PostgresCodable() = #externalMacro(module: "PostgresORMMacros", type: "RawRepPCodableMacro")
