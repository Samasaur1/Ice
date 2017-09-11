//
//  Builder.swift
//  Core
//
//  Created by Jake Heiser on 9/6/17.
//

import Exec
import Regex
import Rainbow

extension SPM {
    
    public func build(release: Bool = false) throws {
        var args = ["build"]
        if release {
            args += ["-c", "release"]
        }
        do {
            try exec(arguments: args).execute(transform: { (t) in
                self.transformBuild(t)
                t.last("\n")
            })
        } catch let error as Exec.Error {
            throw IceError(exitStatus: error.exitStatus)
        }
    }
    
    class CompileMatch: RegexMatch, Matchable {
        static let regex = Regex("Compile Swift Module '(.*)' (.*)$")
        var module: String { return captures[0] }
        var sourceCount: String { return captures[1] }
    }
    
    class LinkMatch: RegexMatch, Matchable {
        static let regex = Regex("Linking (.*)")
        var product: String { return captures[0] }
    }
    
    func transformBuild(_ t: OutputTransformer) {
        t.replace(CompileMatch.self) { "Compile ".dim + "\($0.module) \($0.sourceCount)" }
        t.register(ErrorResponse.self, on: .out)
        t.ignore("^error:", on: .err)
        t.ignore("^terminated\\(1\\)", on: .err)
        t.ignore("^\\s*_\\s*$")
        t.replace(LinkMatch.self) { "\nLink ".blue + $0.product }
    }
    
}

private final class ErrorResponse: SimpleResponse {
    
    class Match: RegexMatch, Matchable {
        static let regex = Regex("(/.*):([0-9]+):([0-9]+): (error|warning): (.*)")
        
        enum ErrorType: String, Capturable {
            case error
            case warning
        }
        
        var path: String { return captures[0] }
        var lineNumber: Int { return captures[1] }
        var columnNumber: Int { return captures[2] }
        var type: ErrorType { return captures[3] }
        var message: String { return captures[4] }
    }
    
    class NoteMatch: RegexMatch, Matchable {
        static let regex = Regex("(/.*):([0-9]+):[0-9]+: note: (.*)")
        var note: String { return captures[2] }
    }
    
    private static var pastMatches: [Match] = []
    
    enum CurrentLine: Int {
        case code
        case underline
        case done
    }
    
    let match: Match
    
    var stream: StdStream = .out
    var currentLine: CurrentLine = .code
    var color: Color?
    var startIndex: String.Index?
    
    init(match: Match) {
        self.match = match
    }
    
    func go() {
        if ErrorResponse.pastMatches.contains(match) {
            stream = .null
            return
        }
        
        let prefix: String
        switch match.type {
        case .error:
            prefix = "● Error:".red.bold
            color = .red
        case .warning:
            prefix = "● Warning:".yellow.bold
            color = .yellow
        }
        stream.output("\n  \(prefix) \(match.message)\n")
        
        ErrorResponse.pastMatches.append(match)
    }
    
    func keepGoing(on line: String) -> Bool {
        switch currentLine {
        case .code:
            startIndex = line.index(where: { $0 != " " })
            stream.output("    " + String(line[startIndex!...]).lightBlack)
            currentLine = .underline
        case .underline:
            stream.output("    " + String(line[startIndex!...]).replacingAll(matching: "~", with: "^").applyingColor(color!))
            currentLine = .done
        case .done:
            if let noteMatch = NoteMatch.match(line) {
                stream.output("    note: " + noteMatch.note + "\n")
                currentLine = .code
            } else if line.hasPrefix("        ") {
                stream.output(String(line[startIndex!...]) + "\n")
                return true
            } else {
                return false
            }
        }
        return true
    }
    
    func stop() {
        let file = match.path.trimmingCurrentDirectory
        var components = file.components(separatedBy: "/")
        let last = components.removeLast()
        let coloredFile = components.joined(separator: "/").dim + "/\(last)"
        stream.output("    at \(coloredFile)" + ":\(match.lineNumber)\n")
    }
    
    
}
