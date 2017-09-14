//
//  RunTests.swift
//  CLITests
//
//  Created by Jake Heiser on 9/14/17.
//

import XCTest

class RunTests: XCTestCase {
    
    func testBasicRun() {
        Runner.execute(args: ["build"], sandbox: .exec)

        let result = Runner.execute(args: ["run"], clean: false)
        XCTAssertEqual(result.exitStatus, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(result.stdout, """
        Hello, world!
        
        """)
    }
    
    func testWatchRun() {
        Runner.execute(args: ["build"], sandbox: .exec)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            writeToSandbox(path: "Sources/Exec/main.swift", contents: "\nprint(\"hey world\")\n")
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
            Runner.interrupt()
        }
        
        let result = Runner.execute(args: ["run", "-w"], clean: false)
        XCTAssertEqual(result.exitStatus, 2)
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(result.stdout, """
        [ice] restarting due to changes...
        Hello, world!
        [ice] restarting due to changes...
        Compile Exec (1 sources)
        Link ./.build/x86_64-apple-macosx10.10/debug/Exec
        hey world
        
        """)
    }
    
}