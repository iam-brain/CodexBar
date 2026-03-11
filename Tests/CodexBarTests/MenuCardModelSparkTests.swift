import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@Suite
struct MenuCardModelSparkTests {
    @Test
    @MainActor
    func showsSparkSessionAndWeeklyMetricsWhenCodexExtraWindowsPresent() throws {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "codex@example.com",
            accountOrganization: nil,
            loginMethod: "Pro")
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 22,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(3000),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 40,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(6000),
                resetDescription: nil),
            tertiary: RateWindow(
                usedPercent: 3,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(5400),
                resetDescription: nil),
            quaternary: RateWindow(
                usedPercent: 17,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(7200),
                resetDescription: nil),
            updatedAt: now,
            identity: identity)
        let metadata = try #require(ProviderDefaults.metadata[.codex])

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: "Pro"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.metrics.count == 4)
        #expect(model.metrics.contains { $0.title == "Spark Session" && $0.percent == 97 })
        #expect(model.metrics.contains { $0.title == "Spark Weekly" && $0.percent == 83 })

        let groups = UsageMenuCardView.metricGroups(provider: .codex, metrics: model.metrics)
        #expect(groups.count == 2)
        let sparkGroup = try #require(groups.last)
        #expect(sparkGroup.title == "GPT-5.3-Codex-Spark")
        #expect(sparkGroup.metrics.map(\.id) == ["tertiary", "quaternary"])
        let sparkSessionMetric = try #require(sparkGroup.metrics.first)
        let sparkWeeklyMetric = try #require(sparkGroup.metrics.last)
        #expect(UsageMenuCardView
            .displayMetricTitle(provider: .codex, metric: sparkSessionMetric, group: sparkGroup) == "Session")
        #expect(UsageMenuCardView
            .displayMetricTitle(provider: .codex, metric: sparkWeeklyMetric, group: sparkGroup) == "Weekly")
    }

    @Test
    @MainActor
    func hidesSparkMetricsForNonProCodexPlans() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.codex])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 22, windowMinutes: 300, resetsAt: now, resetDescription: nil),
            secondary: RateWindow(usedPercent: 40, windowMinutes: 10080, resetsAt: now, resetDescription: nil),
            tertiary: RateWindow(usedPercent: 3, windowMinutes: 300, resetsAt: now, resetDescription: nil),
            quaternary: RateWindow(usedPercent: 17, windowMinutes: 10080, resetsAt: now, resetDescription: nil),
            updatedAt: now,
            identity: ProviderIdentitySnapshot(
                providerID: .codex,
                accountEmail: "codex@example.com",
                accountOrganization: nil,
                loginMethod: "Plus"))

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: "Plus"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.metrics.count == 2)
        #expect(UsageMenuCardView.sparkMetricGroup(provider: .codex, metrics: model.metrics) == nil)
    }
}
