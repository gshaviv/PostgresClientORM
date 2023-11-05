public enum KeyType {
  case camelCase
  case snakeCase
}

@attached(member, names: named(Columns), named(init(row:)), named(encode(row:)))
@attached(extension, conformances: FieldCodable)
public macro Columns(_ type: KeyType) = #externalMacro(module: "PostgresORMMacros", type: "CodingKeysMacro")

@attached(member, names: named(idColumn), named(id), named(Columns), named(_idHolder), named(dbHash), named(init(row:)), named(encode(row:)), named(tableName))
@attached(extension, conformances: TableObject)
public macro TableObject(columns: KeyType, table: String, idType: Any.Type, idName: String = "id", trackDirty: Bool) = #externalMacro(module: "PostgresORMMacros", type: "TablePersistMacro")

@attached(peer)
public macro Column(name: String) = #externalMacro(
    module: "PostgresORMMacros",
    type: "CustomCodingKeyMacro"
)

@attached(peer)
public macro ColumnIgnored() = #externalMacro(module: "PostgresORMMacros", type: "CodingKeyIgnoredMacro")

//@attached(accessor, names: named(get), named(set))
//@attached(peer, names: named(_idHolder))
//public macro ID() = #externalMacro(module: "PostgresORMMacros", type: "IDMacro")
