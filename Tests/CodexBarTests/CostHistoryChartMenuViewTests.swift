import Testing
@testable import CodexBar
@testable import CodexBarCore

@Suite
struct CostHistoryChartMenuViewTests {
    @Test
    @MainActor
    func detailContentUsesOnlySelectedDayModels() {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: 0.12,
                modelsUsed: ["gpt-5.2-codex", "gpt-5.3-codex", "unknown"],
                modelBreakdowns: [
                    .init(modelName: "gpt-5.2-codex", costUSD: 0.06, totalTokens: 60),
                    .init(modelName: "gpt-5.3-codex", costUSD: 0.04, totalTokens: 40),
                    .init(modelName: "unknown", costUSD: nil, totalTokens: 20),
                ]),
            CostUsageDailyReport.Entry(
                date: "2025-12-02",
                inputTokens: 60,
                outputTokens: 12,
                totalTokens: 72,
                costUSD: 0.05,
                modelsUsed: ["gpt-5.4"],
                modelBreakdowns: [
                    .init(modelName: "gpt-5.4", costUSD: 0.05, totalTokens: 72),
                ]),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-02", model: model)

        #expect(detail.models.count == 1)
        #expect(detail.models[0].text.contains("GPT-5.4"))
        #expect(detail.models[0].text.contains("72 tokens"))
        #expect(model.maxDetailLineCount == 3)
    }

    @Test
    @MainActor
    func makeModelDoesNotReserveDetailRowsWithoutBreakdowns() {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 40,
                outputTokens: 10,
                totalTokens: 50,
                costUSD: 0.02,
                modelsUsed: ["gpt-5.2-codex"],
                modelBreakdowns: nil),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)

        #expect(model.maxDetailLineCount == 0)
    }

    @Test
    @MainActor
    func makeModelKeepsMixedKnownAndUnknownDaysVisible() throws {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: nil,
                modelsUsed: ["gpt-5.2-codex", "unknown"],
                modelBreakdowns: [
                    .init(modelName: "gpt-5.2-codex", costUSD: 0.08, totalTokens: 80),
                    .init(modelName: "unknown", costUSD: nil, totalTokens: 40),
                ]),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)
        let point = try #require(model.pointsByDateKey["2025-12-01"])
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-01", model: model)

        #expect(point.displayCostUSD == 0.08)
        #expect(point.actualCostUSD == nil)
        #expect(detail.primary.contains("$0.08"))
        #expect(detail.primary.contains("partial"))
        #expect(detail.primary.contains("120 tokens"))
    }

    @Test
    @MainActor
    func makeModelKeepsUnknownOnlyDaysVisible() throws {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: nil,
                modelsUsed: ["unknown"],
                modelBreakdowns: [
                    .init(modelName: "unknown", costUSD: nil, totalTokens: 120),
                ]),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)
        let point = try #require(model.pointsByDateKey["2025-12-01"])
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-01", model: model)

        #expect(point.displayCostUSD == 0)
        #expect(detail.primary.contains("No priced cost data"))
        #expect(detail.primary.contains("120 tokens"))
    }

    @Test
    @MainActor
    func makeModelCapsDetailRowsForBusyDays() {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 300,
                outputTokens: 60,
                totalTokens: 360,
                costUSD: 0.18,
                modelsUsed: ["gpt-5", "gpt-5-mini", "gpt-5-pro", "gpt-5.2", "unknown"],
                modelBreakdowns: [
                    .init(modelName: "gpt-5", costUSD: 0.04, totalTokens: 80),
                    .init(modelName: "gpt-5-mini", costUSD: 0.02, totalTokens: 70),
                    .init(modelName: "gpt-5-pro", costUSD: 0.05, totalTokens: 60),
                    .init(modelName: "gpt-5.2", costUSD: 0.04, totalTokens: 80),
                    .init(modelName: "unknown", costUSD: nil, totalTokens: 70),
                ]),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-01", model: model)

        #expect(model.maxDetailLineCount == 4)
        #expect(detail.models.count == 4)
        #expect(detail.models.last?.text == "2 more models")
    }
}
