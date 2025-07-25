import XCTest

final class VoiceAgentTests: XCTestCase {
    func testExample() {
        XCTAssertTrue(true)
    }

    #if !os(macOS)
    func testUnsupportedPlatformExecutable() throws {
        let exec = productsDirectory.appendingPathComponent("VoiceAgent")
        let process = Process()
        process.executableURL = exec
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        XCTAssertEqual(output?.trimmingCharacters(in: .whitespacesAndNewlines), "VoiceAgent is only supported on macOS.")
    }
    #endif

    private var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("Products directory not found")
        #else
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidate1 = root.appendingPathComponent(".build/x86_64-unknown-linux-gnu/debug")
        let candidate2 = root.appendingPathComponent(".build/debug")
        if FileManager.default.fileExists(atPath: candidate1.path) {
            return candidate1
        }
        return candidate2
        #endif
    }
}
