//
//  GenerateCompletions.swift
//  Ice
//
//  Created by Jake Heiser on 9/10/17.
//

import SwiftCLI

enum ShellCompletionFunctions: String {
    case listRegistry = "_list_registry"
    case listDependencies = "_list_dependencies"
    case listTargets = "_list_targets"
}

extension ShellCompletion {
    static func function(_ function: ShellCompletionFunctions) -> ShellCompletion {
        return .function(function.rawValue)
    }
}

class GenerateCompletionsCommand: Command {
    
    let name = "generate-completions"
    let shortDescription = "Generates zsh completions"
    let longDescription = """
    Generates zsh completions. You should run this command by sending the output to a file named `_ice`
    on your $fpath (e.g. `ice generate-completions > ~/.oh-my-zsh/completions/_ice`)
    """
    
    let cli: CLI
    
    init(cli: CLI) {
        self.cli = cli
    }
    
    func execute() throws {
        let completionGenerator = ZshCompletionGenerator(cli: cli, functions: generateFunctions())
        completionGenerator.writeCompletions()
    }
    
    func generateFunctions() -> [String: String] {
        return [
            ShellCompletionFunctions.listRegistry.rawValue: """
            local packages
            packages=( $(grep name ~/.icebox/Registry/local.json ~/.icebox/Registry/shared/Registry/*.json | grep -o '"[^"]*"' | grep -v "name" | cut -c 2- | rev | cut -c 2- | rev) )
            _describe '' packages
            """,
            ShellCompletionFunctions.listDependencies.rawValue: """
            local dependencies
            dependencies=( $(grep -e "\\.package" Package.swift | grep -o 'url: "[^"]*"' | grep -o '/[^/]*"' | cut -c 2- | rev | cut -c 2- | rev) )
            _describe '' dependencies
            """,
            ShellCompletionFunctions.listTargets.rawValue: """
            local targets
            targets=( $(grep -e "\\.target\\|\\.testTarget" Package.swift | grep -o 'name: "[^"]*"' | cut -c 8- | rev | cut -c 2- | rev) )
            _describe '' targets
            """,
        ]
    }
    
}
