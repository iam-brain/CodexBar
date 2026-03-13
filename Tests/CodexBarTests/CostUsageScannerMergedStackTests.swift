import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct CostUsageScannerMergedStackTests {
    @Test
    func codexDailyReportRecoversModelFromSessionMetaInstructions() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 24)
        let iso0 = env.isoString(for: day)
        let iso1 = env.isoString(for: day.addingTimeInterval(1))

        let sessionMeta: [String: Any] = [
            "type": "session_meta",
            "timestamp": iso0,
            "payload": [
                "id": "sess-meta-model",
                "base_instructions": [
                    "text": "You are GPT-5.2 running in the Codex CLI.",
                ],
            ],
        ]
        let tokenCountWithoutModel: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso1,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 100,
                        "cached_input_tokens": 20,
                        "output_tokens": 10,
                    ],
                ],
            ],
        ]

        _ = try env.writeCodexSessionFile(
            day: day,
            filename: "session-meta-model.jsonl",
            contents: env.jsonl([sessionMeta, tokenCountWithoutModel]))

        var options = CostUsageScanner.Options(
            codexSessionsRoot: env.codexSessionsRoot,
            claudeProjectsRoots: nil,
            cacheRoot: env.cacheRoot)
        options.refreshMinIntervalSeconds = 0

        let report = CostUsageScanner.loadDailyReport(
            provider: .codex,
            since: day,
            until: day,
            now: day,
            options: options)
        let entry = try #require(report.data.first)
        #expect(entry.modelsUsed == ["gpt-5.2-codex"])
        #expect(entry.modelBreakdowns?.contains {
            $0.modelName == "gpt-5.2-codex" && $0.costUSD != nil && $0.totalTokens == 110
        } == true)
    }

    @Test
    func codexDailyReportUsesUnknownModelWhenMetadataIsMissing() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 24)
        let iso0 = env.isoString(for: day)

        let tokenCountWithoutModel: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso0,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 100,
                        "cached_input_tokens": 20,
                        "output_tokens": 10,
                    ],
                ],
            ],
        ]

        _ = try env.writeCodexSessionFile(
            day: day,
            filename: "session-unknown-model.jsonl",
            contents: env.jsonl([tokenCountWithoutModel]))

        var options = CostUsageScanner.Options(
            codexSessionsRoot: env.codexSessionsRoot,
            claudeProjectsRoots: nil,
            cacheRoot: env.cacheRoot)
        options.refreshMinIntervalSeconds = 0

        let report = CostUsageScanner.loadDailyReport(
            provider: .codex,
            since: day,
            until: day,
            now: day,
            options: options)
        let entry = try #require(report.data.first)
        #expect(entry.modelsUsed == ["unknown"])
        #expect(entry.modelBreakdowns?.contains {
            $0.modelName == "unknown" && $0.costUSD == nil && $0.totalTokens == 110
        } == true)
        #expect(report.summary?.totalCostUSD == nil)
    }

    @Test
    func codexDailyReportNilCostWhenKnownAndUnknownModelsMix() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 22)
        let iso0 = env.isoString(for: day)
        let iso1 = env.isoString(for: day.addingTimeInterval(1))
        let iso2 = env.isoString(for: day.addingTimeInterval(2))

        let knownModel = "openai/gpt-5.2-codex"
        let turnContext: [String: Any] = [
            "type": "turn_context",
            "timestamp": iso0,
            "payload": [
                "model": knownModel,
            ],
        ]
        let knownTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso1,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 100,
                        "cached_input_tokens": 20,
                        "output_tokens": 10,
                    ],
                    "model": knownModel,
                ],
            ],
        ]
        let unknownTokenCount: [String: Any] = [
            "type": "event_msg",
            "timestamp": iso2,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 80,
                        "cached_input_tokens": 0,
                        "output_tokens": 8,
                    ],
                ],
            ],
        ]

        _ = try env.writeCodexSessionFile(
            day: day,
            filename: "session-known-model.jsonl",
            contents: env.jsonl([turnContext, knownTokenCount]))
        _ = try env.writeCodexSessionFile(
            day: day,
            filename: "session-unknown-model.jsonl",
            contents: env.jsonl([unknownTokenCount]))

        var options = CostUsageScanner.Options(
            codexSessionsRoot: env.codexSessionsRoot,
            claudeProjectsRoots: nil,
            cacheRoot: env.cacheRoot)
        options.refreshMinIntervalSeconds = 0

        let report = CostUsageScanner.loadDailyReport(
            provider: .codex,
            since: day,
            until: day,
            now: day,
            options: options)

        let entry = try #require(report.data.first)
        #expect(entry.modelsUsed == ["gpt-5.2-codex", "unknown"])
        #expect(entry.costUSD == nil)
        #expect(entry.modelBreakdowns?.contains {
            $0.modelName == "gpt-5.2-codex" && $0.costUSD != nil && $0.totalTokens == 110
        } == true)
        #expect(entry.modelBreakdowns?.contains {
            $0.modelName == "unknown" && $0.costUSD == nil && $0.totalTokens == 88
        } == true)
        #expect(report.summary?.totalCostUSD == nil)
    }

    @Test
    func codexDailyReportKeepsAllModelBreakdownsForBusyDays() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }

        let day = try env.makeLocalNoon(year: 2025, month: 12, day: 23)
        let models = [
            "openai/gpt-5.1-codex",
            "openai/gpt-5.2-codex",
            "openai/gpt-5.3-codex",
            "openai/gpt-5.4",
        ]

        for (index, model) in models.enumerated() {
            let timestamp = env.isoString(for: day.addingTimeInterval(TimeInterval(index)))
            let tokenCount: [String: Any] = [
                "type": "event_msg",
                "timestamp": timestamp,
                "payload": [
                    "type": "token_count",
                    "info": [
                        "last_token_usage": [
                            "input_tokens": 100 + index,
                            "cached_input_tokens": 10,
                            "output_tokens": 10,
                        ],
                        "model": model,
                    ],
                ],
            ]

            _ = try env.writeCodexSessionFile(
                day: day,
                filename: "session-\(index).jsonl",
                contents: env.jsonl([tokenCount]))
        }

        var options = CostUsageScanner.Options(
            codexSessionsRoot: env.codexSessionsRoot,
            claudeProjectsRoots: nil,
            cacheRoot: env.cacheRoot)
        options.refreshMinIntervalSeconds = 0

        let report = CostUsageScanner.loadDailyReport(
            provider: .codex,
            since: day,
            until: day,
            now: day,
            options: options)
        let entry = try #require(report.data.first)
        #expect(entry.modelsUsed == [
            "gpt-5.1-codex",
            "gpt-5.2-codex",
            "gpt-5.3-codex",
            "gpt-5.4",
        ])
        #expect(entry.modelBreakdowns?.map(\.modelName).sorted() == [
            "gpt-5.1-codex",
            "gpt-5.2-codex",
            "gpt-5.3-codex",
            "gpt-5.4",
        ])
    }
}
