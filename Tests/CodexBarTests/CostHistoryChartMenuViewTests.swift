import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@Suite
struct CostHistoryChartMenuViewTests {
    @Test
    @MainActor
    func makeSnapshotBuildsRollingThirtyDayWindowEndingToday() throws {
        let now = try #require(Self.date(year: 2026, month: 3, day: 12, hour: 9))
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2026-03-12",
                inputTokens: 120,
                outputTokens: 30,
                totalTokens: 150,
                costUSD: 0.25,
                modelsUsed: ["gpt-5.4-codex"],
                modelBreakdowns: nil),
        ]

        let snapshot = CostHistoryChartMenuView.TestSupport.makeSnapshot(daily: daily, now: now)

        #expect(snapshot.points.count == 30)
        #expect(snapshot.points.first?.dayKey == "2026-02-11")
        #expect(snapshot.points.last?.dayKey == "2026-03-12")

        let today = try #require(snapshot.points.last)
        #expect(today.isPlaceholder == false)
        #expect(today.actualCostUSD == 0.25)

        let earlierDays = snapshot.points.dropLast()
        #expect(earlierDays.contains(where: { !$0.isPlaceholder }) == false)
        #expect(earlierDays.allSatisfy { $0.displayCostUSD == 0 })
    }

    @Test
    @MainActor
    func makeSnapshotTreatsNilAndZeroCostDaysAsPlaceholders() throws {
        let now = try #require(Self.date(year: 2026, month: 3, day: 12, hour: 9))
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2026-03-10",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: nil,
                modelsUsed: ["unknown"],
                modelBreakdowns: nil),
            CostUsageDailyReport.Entry(
                date: "2026-03-11",
                inputTokens: 90,
                outputTokens: 10,
                totalTokens: 100,
                costUSD: 0,
                modelsUsed: ["claude-sonnet-4-5"],
                modelBreakdowns: nil),
            CostUsageDailyReport.Entry(
                date: "2026-03-12",
                inputTokens: 70,
                outputTokens: 10,
                totalTokens: 80,
                costUSD: 0.08,
                modelsUsed: ["claude-sonnet-4-5"],
                modelBreakdowns: nil),
        ]

        let snapshot = CostHistoryChartMenuView.TestSupport.makeSnapshot(
            provider: .claude,
            daily: daily,
            now: now)

        let nilCostDay = try #require(snapshot.points.first { $0.dayKey == "2026-03-10" })
        #expect(nilCostDay.hasUsage == true)
        #expect(nilCostDay.isPlaceholder == true)
        #expect(nilCostDay.displayCostUSD == 0)
        #expect(nilCostDay.actualCostUSD == nil)

        let zeroCostDay = try #require(snapshot.points.first { $0.dayKey == "2026-03-11" })
        #expect(zeroCostDay.hasUsage == true)
        #expect(zeroCostDay.isPlaceholder == true)
        #expect(zeroCostDay.displayCostUSD == 0)
        #expect(zeroCostDay.actualCostUSD == 0)

        let pricedDay = try #require(snapshot.points.first { $0.dayKey == "2026-03-12" })
        #expect(pricedDay.isPlaceholder == false)
        #expect(pricedDay.displayCostUSD > 0)
        #expect(pricedDay.actualCostUSD == 0.08)
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
