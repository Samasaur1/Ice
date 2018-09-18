//
//  Add.swift
//  Ice
//
//  Created by Jake Heiser on 7/21/17.
//

import Foundation
import IceKit
import SwiftCLI

class AddCommand: IceObject, Command {
    
    let name = "add"
    let shortDescription = "Adds the given package as a dependency"
    
    let dependency = Parameter(completion: .function(.listRegistry))
    
    let targets = Key<String>("-t", "--targets", description: "List of targets which should depend on this dependency")
    let noInteractive = Flag("-n", "--no-interactive", description: "Do not prompt for targets if none are supplied")
    
    let version = Key<Version>("-w", "--version", description: "The version of the dependency to depend on")
    let branch = Key<String>("-b", "--branch", description: "The branch of the dependency to depend on")
    let sha = Key<String>("-s", "--sha", description: "The commit hash of the dependency to depend on")
    let local = Flag("-l", "--local", description: "Add this dependency as a local dependency")
    
    var optionGroups: [OptionGroup] {
        return [.atMostOne(version, branch, sha, local)]
    }
    
    func execute() throws {
        guard let ref = RepositoryReference(blob: dependency.value, registry: registry) else {
            throw IceError(message: "not a valid package reference")
        }
        
        verboseOut <<< "Resolving url: \(ref.url)"
        
        let requirement: Package.Dependency.Requirement
        if let version = version.value {
            requirement = .init(version: version)
        } else if let branch = branch.value {
            requirement = .init(type: .branch, lowerBound: nil, upperBound: nil, identifier: branch)
        } else if let sha = sha.value {
            requirement = .init(type: .revision, lowerBound: nil, upperBound: nil, identifier: sha)
        } else if local.value {
            requirement = .init(type: .localPackage, lowerBound: nil, upperBound: nil, identifier: nil)
        } else if let latestVersion = try ref.latestVersion() {
            requirement = .init(version: latestVersion)
        } else {
            throw IceError(message: "no tagged versions found; manually specify version with --version, --branch, or --sha")
        }
        
        verboseOut <<< "Resolving at version: \(requirement)"
        
        var package = try loadPackage()
        
        if package.dependencies.contains(where: { $0.url == ref.url }) {
            throw IceError(message: "package already depends on \(ref.url)")
        }
        
        verboseOut <<< "Loaded package: \(package.name)"
        
        package.addDependency(ref: ref, requirement: requirement)
        try package.sync()
        
        try SPM().resolve()
        
        let libs = package.retrieveLibrariesOfDependency(named: ref.name)
        if libs.count > 1 {
            stdout <<< ""
            stdout <<< "Note: ".bold.blue + "this dependency offers multiple libraries (" + libs.joined(separator: ", ") + ")"
        }
        
        for lib in libs {
            if let targetString = targets.value {
                let targets = targetString.components(separatedBy: ",")
                try targets.forEach { try package.depend(target: $0, on: lib) }
            } else if package.targets.count == 1 {
                try package.depend(target: package.targets[0].name, on: lib)
            } else if !noInteractive.value {
                stdout <<< ""
                stdout <<< "Which targets depend on \(lib)?"
                stdout <<< ""
                
                let possibleTargets = package.targets.filter({ $0.type != .system })
                
                let ids = "123456789abcdefghijklmnopqrstuvwxyz".prefix(possibleTargets.count)
                for (index, target) in possibleTargets.enumerated() {
                    stdout <<< "  " + String(ids[ids.index(ids.startIndex, offsetBy: index)]) + "  " + target.name
                }
                stdout <<< ""
                
                let targetString = Input.readLine(prompt: "> ", validation: { (input) -> Bool in
                    let allowed = CharacterSet(charactersIn: ids + ", ")
                    return input.rangeOfCharacter(from: allowed.inverted) == nil
                })
                let distances = targetString.compactMap { ids.index(of: $0) }
                let targets = distances.map { possibleTargets[ids.distance(from: ids.startIndex, to: $0)] }
                try targets.forEach { try package.depend(target: $0.name, on: lib) }
            }
        }
        
        try package.sync()
    }
    
}