public enum KeyType {
  case camelCase
  case snakeCase
}

@attached(member, names: named(CodingKeys))
public macro CodingKeys(_ type: KeyType) = #externalMacro(module: "CodingKeysGeneratorMacros", type: "CodingKeysMacro")

@attached(member, names: named(CodingKeys), named(Key), named(idColumn), named(dbHash), named(init(from:)), named(encode(to:)))
@attached(extension, conformances: TableObject, FieldGroup)
public macro TablePersist(_ type: KeyType, trackDirty: Bool) = #externalMacro(module: "CodingKeysGeneratorMacros", type: "TablePersistMacro")

@attached(peer)
public macro CodingKey(custom: String) = #externalMacro(
    module: "CodingKeysGeneratorMacros",
    type: "CustomCodingKeyMacro"
)

@attached(peer)
public macro CodingKeyIgnored() = #externalMacro(module: "CodingKeysGeneratorMacros", type: "CodingKeyIgnoredMacro")

@attached(accessor, names: named(get), named(set))
@attached(peer, names: named(_idHolder))
public macro ID() = #externalMacro(module: "CodingKeysGeneratorMacros", type: "IDMacro")
