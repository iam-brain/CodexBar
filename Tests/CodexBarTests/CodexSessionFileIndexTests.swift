import Foundation
import Testing
@testable import CodexBarCore

// swiftlint:disable line_length
struct CodexSessionFileIndexTests {
    @Test
    func `prefers rollout filename owner over copied metadata`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let sessionID = "019f55a1-7f6e-70c0-8e4f-f5bbefa9b7ac"
        let copied = env.root.appendingPathComponent("copied-metadata.jsonl")
        let owner = env.root.appendingPathComponent("rollout-2030-01-01T00-00-00-\(sessionID).jsonl")
        let metadata = #"{"type":"session_meta","payload":{"id":"\#(sessionID)"}}"# + "\n"
        try metadata.write(to: copied, atomically: true, encoding: .utf8)
        try metadata.write(to: owner, atomically: true, encoding: .utf8)
        let index = CostUsageScanner.CodexSessionFileIndex(files: [copied, owner], roots: [])
        #expect(try index.fileURL(for: sessionID) == owner)
    }

    @Test
    func `does not use copied metadata as ancestor ownership`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let ancestorID = "019f55a1-7f6e-70c0-8e4f-f5bbefa9b7ac"
        let ownerID = "019f5844-e48b-7622-bc4a-9480d42e69cb"
        let owner = env.root.appendingPathComponent("rollout-2030-01-01T00-00-00-\(ownerID).jsonl")
        let copiedMetadata = #"{"type":"session_meta","payload":{"id":"\#(ancestorID)"}}"# + "\n"
        try copiedMetadata.write(to: owner, atomically: true, encoding: .utf8)
        let index = CostUsageScanner.CodexSessionFileIndex(files: [owner], roots: [])
        #expect(try index.fileURL(for: ownerID) == owner)
        #expect(try index.fileURL(for: ancestorID) == nil)
    }

    @Test
    func `inherited totals accept filename owner with copied ancestor metadata`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let ancestorID = "019f55a1-7f6e-70c0-8e4f-f5bbefa9b7ac"
        let ownerID = "019f5844-e48b-7622-bc4a-9480d42e69cb"
        let timestamp = "2030-01-01T12:00:00Z"
        let owner = env.root.appendingPathComponent("rollout-2030-01-01T00-00-00-\(ownerID).jsonl")
        let contents = [
            #"{"type":"session_meta","timestamp":"\#(timestamp)","payload":{"id":"\#(ancestorID)"}}"#,
            #"{"type":"event_msg","timestamp":"\#(timestamp)","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":0}}}}"#,
        ].joined(separator: "\n") + "\n"
        try contents.write(to: owner, atomically: true, encoding: .utf8)
        let index = CostUsageScanner.CodexSessionFileIndex(files: [owner], roots: [])
        let resolver = CostUsageScanner.CodexInheritedTotalsResolver(fileIndex: index, checkCancellation: nil)
        switch try resolver.inheritedTotals(for: ownerID, atOrBefore: timestamp) {
        case let .resolved(totals): #expect(totals?.input == 100)
        case .unresolved: Issue.record("Expected filename-owned copied metadata to resolve")
        }
    }

    @Test
    func `fails open when copied metadata ownership is ambiguous`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let sessionID = "ambiguous-session"
        let first = env.root.appendingPathComponent("first.jsonl")
        let second = env.root.appendingPathComponent("second.jsonl")
        let metadata = #"{"type":"session_meta","payload":{"id":"\#(sessionID)"}}"# + "\n"
        try metadata.write(to: first, atomically: true, encoding: .utf8)
        try metadata.write(to: second, atomically: true, encoding: .utf8)
        let index = CostUsageScanner.CodexSessionFileIndex(files: [second, first], roots: [])
        #expect(try index.fileURL(for: sessionID) == nil)
    }
}

// swiftlint:enable line_length
