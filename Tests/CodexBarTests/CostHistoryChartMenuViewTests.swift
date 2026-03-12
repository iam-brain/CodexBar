import Testing
@testable import CodexBar
@testable import CodexBarCore

@Suite
struct CostHistoryChartMenuViewTests {
    @Test
    @MainActor
    func makeModelBackfillsEmptyDaysBetweenEntries() throws {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: 0.08,
                modelsUsed: ["gpt-5.2-codex"],
                modelBreakdowns: [
                    .init(modelName: "gpt-5.2-codex", costUSD: 0.08),
                ]),
            CostUsageDailyReport.Entry(
                date: "2025-12-03",
                inputTokens: 50,
                outputTokens: 10,
                totalTokens: 60,
                costUSD: 0.03,
                modelsUsed: ["gpt-5.3-codex"],
                modelBreakdowns: [
                    .init(modelName: "gpt-5.3-codex", costUSD: 0.03),
                ]),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)

        #expect(model.points.count == 3)
        let middleDay = try #require(model.pointsByDateKey["2025-12-02"])
        #expect(middleDay.isPlaceholder == true)
        #expect(middleDay.chartCostUSD == 0)
        #expect(middleDay.actualCostUSD == nil)
    }

    @Test
    @MainActor
    func makeModelKeepsUnknownCostDaysDistinctFromBackfilledGaps() throws {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: nil,
                modelsUsed: ["unknown"],
                modelBreakdowns: nil),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)

        let point = try #require(model.pointsByDateKey["2025-12-01"])
        #expect(point.isPlaceholder == false)
        #expect(point.hasUsage == true)
        #expect(point.actualCostUSD == nil)
        #expect(point.chartCostUSD == 0)
    }
}
