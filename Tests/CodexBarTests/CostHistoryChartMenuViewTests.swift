import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@Suite
struct CostHistoryChartMenuViewTests {
    @Test
    @MainActor
    func makeDayStatesBuildsRollingThirtyDayWindowEndingToday() throws {
        let now = try #require(Self.date(year: 2026, month: 3, day: 12, hour: 9))
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2026-03-12",
                inputTokens: 120,
                outputTokens: 30,
                totalTokens: 150,
                costUSD: 0.25,
                modelsUsed: ["gpt-5.4"],
                modelBreakdowns: nil),
        ]

        let days = CostHistoryChartMenuView.TestSupport.makeDayStates(daily: daily, now: now)

        #expect(days.count == 30)
        #expect(days.first?.dayKey == "2026-02-11")
        #expect(days.last?.dayKey == "2026-03-12")

        let today = try #require(days.last)
        #expect(today.hasEntry == true)
        #expect(today.costUSD == 0.25)

        let earlierDays = days.dropLast()
        #expect(earlierDays.allSatisfy { $0.hasEntry == false })
        #expect(earlierDays.allSatisfy { $0.costUSD == 0 })
    }

    @Test
    @MainActor
    func detailSummaryTreatsPartialAndUnknownDaysDifferently() {
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
            CostUsageDailyReport.Entry(
                date: "2025-12-02",
                inputTokens: 90,
                outputTokens: 10,
                totalTokens: 100,
                costUSD: nil,
                modelsUsed: ["unknown"],
                modelBreakdowns: [
                    .init(modelName: "unknown", costUSD: nil, totalTokens: 100),
                ]),
        ]

        let partial = CostHistoryChartMenuView.TestSupport.detailSummary(
            selectedDateKey: "2025-12-01",
            daily: daily)
        let unknownOnly = CostHistoryChartMenuView.TestSupport.detailSummary(
            selectedDateKey: "2025-12-02",
            daily: daily)

        #expect(partial.primary.contains("$0.08"))
        #expect(partial.primary.contains("partial"))
        #expect(partial.primary.contains("120 tokens"))
        #expect(unknownOnly.primary.contains("No priced cost data"))
        #expect(unknownOnly.primary.contains("100 tokens"))
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int) -> Date? {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date
    }
}
