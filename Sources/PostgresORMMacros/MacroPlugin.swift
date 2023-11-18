import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PostgressORMMacros: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodingKeysMacro.self,
        CustomCodingKeyMacro.self,
        CodingKeyIgnoredMacro.self,
        TablePersistMacro.self,
    ]
}
