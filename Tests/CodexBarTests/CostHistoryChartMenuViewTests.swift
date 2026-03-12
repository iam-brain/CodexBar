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
    func makeModelOnlyBackfillsMissingDays() {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: 0.08,
                modelsUsed: ["gpt-5.2-codex"],
                modelBreakdowns: nil),
            CostUsageDailyReport.Entry(
                date: "2025-12-02",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: nil,
                modelsUsed: ["unknown"],
                modelBreakdowns: nil),
            CostUsageDailyReport.Entry(
                date: "2025-12-03",
                inputTokens: 50,
                outputTokens: 10,
                totalTokens: 60,
                costUSD: 0.03,
                modelsUsed: ["gpt-5.3-codex"],
                modelBreakdowns: nil),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)

        #expect(model.points.count == 2)
        #expect(model.pointsByDateKey["2025-12-02"] == nil)
    }

    @Test
    @MainActor
    func makeModelIgnoresMalformedBoundaryDatesWhenBackfilling() throws {
        let daily = [
            CostUsageDailyReport.Entry(
                date: "not-a-date",
                inputTokens: 80,
                outputTokens: 10,
                totalTokens: 90,
                costUSD: 0.05,
                modelsUsed: ["gpt-5.2-codex"],
                modelBreakdowns: nil),
            CostUsageDailyReport.Entry(
                date: "2025-12-03",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: 0.08,
                modelsUsed: ["gpt-5.2-codex"],
                modelBreakdowns: nil),
            CostUsageDailyReport.Entry(
                date: "2025-12-05",
                inputTokens: 50,
                outputTokens: 10,
                totalTokens: 60,
                costUSD: 0.03,
                modelsUsed: ["gpt-5.3-codex"],
                modelBreakdowns: nil),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily)

        #expect(model.points.count == 3)
        let missingDay = try #require(model.pointsByDateKey["2025-12-04"])
        #expect(missingDay.isPlaceholder == true)
    }
}
