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
                modelsUsed: ["gpt-5.4-codex"],
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
    func makeDayStatesKeepsNilAndZeroCostDaysAsEmptySlots() throws {
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

        let days = CostHistoryChartMenuView.TestSupport.makeDayStates(
            provider: .claude,
            daily: daily,
            now: now)

        let nilCostDay = try #require(days.first { $0.dayKey == "2026-03-10" })
        #expect(nilCostDay.hasEntry == true)
        #expect(nilCostDay.costUSD == 0)

        let zeroCostDay = try #require(days.first { $0.dayKey == "2026-03-11" })
        #expect(zeroCostDay.hasEntry == true)
        #expect(zeroCostDay.costUSD == 0)

        let pricedDay = try #require(days.first { $0.dayKey == "2026-03-12" })
        #expect(pricedDay.hasEntry == true)
        #expect(pricedDay.costUSD == 0.08)
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
