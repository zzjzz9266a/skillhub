import Foundation
import Testing
@testable import SkillHub

struct SourceParserTests {
    @Test func gitHTTPS() {
        let result = SourceParser.parse("https://github.com/obra/superpowers.git")
        guard case .git = result else {
            Issue.record("Expected git, got \(String(describing: result))")
            return
        }
        #expect(Bool(true))
    }

    @Test func gitSSH() {
        let result = SourceParser.parse("git@github.com:user/repo.git")
        guard case .git = result else {
            Issue.record("Expected git, got \(String(describing: result))")
            return
        }
        #expect(Bool(true))
    }

    @Test func npmScoped() {
        let result = SourceParser.parse("@scope/package-name")
        guard case .npm(let name) = result else {
            Issue.record("Expected npm, got \(String(describing: result))")
            return
        }
        #expect(name == "@scope/package-name")
    }

    @Test func npmUnscopedPackageName() {
        let result = SourceParser.parse("package-name")
        guard case .npm(let name) = result else {
            Issue.record("Expected npm, got \(String(describing: result))")
            return
        }
        #expect(name == "package-name")
    }

    @Test func localDirectory() {
        let tmpDir = FileManager.default.temporaryDirectory.path
        let result = SourceParser.parse(tmpDir)
        guard case .local = result else {
            Issue.record("Expected local, got \(String(describing: result))")
            return
        }
        #expect(Bool(true))
    }

    @Test func invalidInput() {
        let result = SourceParser.parse("not/a/local/path")
        #expect(result == nil)
    }
}
