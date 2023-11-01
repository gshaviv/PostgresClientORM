public enum KeyType {
  case camelCase
  case snakeCase
}
internal protocol TableObject {}
protocol TestP {}

@attached(member, names: named(CodingKeys))
public macro CodingKeys(_ type: KeyType) = #externalMacro(module: "CodingKeysGeneratorMacros", type: "CodingKeysMacro")

@attached(member, names: named(CodingKeys), named(Key), named(idColumn), named(dbHash))
//@attached(extension, conformances: Equatable, TestP, names: named(required))
public macro TablePersist(_ type: KeyType, trackDirty: Bool) = #externalMacro(module: "CodingKeysGeneratorMacros", type: "TablePersistMacro")

@attached(peer)
public macro CodingKey(custom: String) = #externalMacro(
    module: "CodingKeysGeneratorMacros",
    type: "CustomCodingKeyMacro"
)

@attached(peer)
public macro CodingKeyIgnored() = #externalMacro(module: "CodingKeysGeneratorMacros", type: "CodingKeyIgnoredMacro")
