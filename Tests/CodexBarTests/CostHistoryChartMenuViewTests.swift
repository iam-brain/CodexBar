import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@Suite
struct CostHistoryChartMenuViewTests {
    @Test
    @MainActor
    func detailContentUsesOnlySelectedDayModels() throws {
        let now = try #require(Self.date(year: 2025, month: 12, day: 2, hour: 9))
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

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily, now: now)
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-02", model: model)

        #expect(detail.models.count == 1)
        #expect(detail.models[0].text.contains("GPT-5.4"))
        #expect(detail.models[0].text.contains("72 tokens"))
        #expect(model.maxDetailLineCount == 3)
    }

    @Test
    @MainActor
    func makeModelDoesNotReserveDetailRowsWithoutBreakdowns() throws {
        let now = try #require(Self.date(year: 2025, month: 12, day: 1, hour: 9))
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

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily, now: now)

        #expect(model.maxDetailLineCount == 0)
    }

    @Test
    @MainActor
    func makeModelKeepsMixedKnownAndUnknownDaysVisible() throws {
        let now = try #require(Self.date(year: 2025, month: 12, day: 1, hour: 9))
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

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily, now: now)
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
        let now = try #require(Self.date(year: 2025, month: 12, day: 1, hour: 9))
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

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily, now: now)
        let point = try #require(model.pointsByDateKey["2025-12-01"])
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-01", model: model)

        #expect(point.displayCostUSD == 0)
        #expect(detail.primary.contains("No priced cost data"))
        #expect(detail.primary.contains("120 tokens"))
    }

    @Test
    @MainActor
    func makeModelCapsDetailRowsForBusyDays() throws {
        let now = try #require(Self.date(year: 2025, month: 12, day: 1, hour: 9))
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

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily, now: now)
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-01", model: model)

        #expect(model.maxDetailLineCount == 4)
        #expect(detail.models.count == 4)
        #expect(detail.models.last?.text == "2 more models")
    }

    @Test
    @MainActor
    func makeModelKeepsZeroCostDaysPriced() throws {
        let now = try #require(Self.date(year: 2025, month: 12, day: 1, hour: 9))
        let daily = [
            CostUsageDailyReport.Entry(
                date: "2025-12-01",
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120,
                costUSD: 0,
                modelsUsed: ["gpt-5.3-codex-spark"],
                modelBreakdowns: [
                    .init(modelName: "gpt-5.3-codex-spark", costUSD: 0, totalTokens: 120),
                ]),
        ]

        let model = CostHistoryChartMenuView.makeModel(provider: .codex, daily: daily, now: now)
        let point = try #require(model.pointsByDateKey["2025-12-01"])
        let detail = CostHistoryChartMenuView.detailContent(selectedDateKey: "2025-12-01", model: model)

        #expect(point.displayCostUSD == 0)
        #expect(point.actualCostUSD == 0)
        #expect(detail.primary.contains("$0.00"))
        #expect(detail.primary.contains("120 tokens"))
        #expect(detail.models.first?.text.contains("$0.00") == true)
        #expect(detail.models.first?.text.contains("unpriced") == false)
    }

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
