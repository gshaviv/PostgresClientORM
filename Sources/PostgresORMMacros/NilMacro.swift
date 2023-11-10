//
//  File.swift
//  
//
//  Created by Guy Shaviv on 10/11/2023.
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct NilMacro: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) -> ExprSyntax {
    guard node.argumentList.isEmpty else {
      fatalError("#nil doesn't take any arguments")
    }

    return """
       Optional<Bool>.none
    """
  }
}
