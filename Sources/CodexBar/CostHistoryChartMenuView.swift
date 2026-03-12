import Charts
import CodexBarCore
import SwiftUI

@MainActor
struct CostHistoryChartMenuView: View {
    typealias DailyEntry = CostUsageDailyReport.Entry

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let costUSD: Double
        let totalTokens: Int?

        init(date: Date, costUSD: Double, totalTokens: Int?) {
            self.date = date
            self.costUSD = costUSD
            self.totalTokens = totalTokens
            self.id = "\(Int(date.timeIntervalSince1970))-\(costUSD)"
        }
    }

    private let provider: UsageProvider
    private let daily: [DailyEntry]
    private let totalCostUSD: Double?
    private let width: CGFloat
    @State private var selectedDateKey: String?

    init(provider: UsageProvider, daily: [DailyEntry], totalCostUSD: Double?, width: CGFloat) {
        self.provider = provider
        self.daily = daily
        self.totalCostUSD = totalCostUSD
        self.width = width
    }

    var body: some View {
        let model = Self.makeModel(provider: self.provider, daily: self.daily)
        VStack(alignment: .leading, spacing: 10) {
            if model.points.isEmpty {
                Text("No cost history data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(model.points) { point in
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Cost", point.costUSD))
                            .foregroundStyle(point.costUSD > 0 ? model.barColor : Color.clear)
                    }
                    if let peak = Self.peakPoint(model: model) {
                        let capStart = max(peak.costUSD - Self.capHeight(maxValue: model.maxCostUSD), 0)
                        BarMark(
                            x: .value("Day", peak.date, unit: .day),
                            yStart: .value("Cap start", capStart),
                            yEnd: .value("Cap end", peak.costUSD))
                            .foregroundStyle(Color(nsColor: .systemYellow))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: model.axisDates) { _ in
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisTick().foregroundStyle(Color.clear)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 130)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if let rect = self.selectionBandRect(model: model, proxy: proxy, geo: geo) {
                                Rectangle()
                                    .fill(Self.selectionBandColor)
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .allowsHitTesting(false)
                            }
                            MouseLocationReader { location in
                                self.updateSelection(location: location, model: model, proxy: proxy, geo: geo)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                    }
                }

                let detail = self.detailLines(model: model)
                VStack(alignment: .leading, spacing: 0) {
                    Text(detail.primary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 16, alignment: .leading)
                    Text(detail.secondary ?? " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 16, alignment: .leading)
                        .opacity(detail.secondary == nil ? 0 : 1)
                }
            }

            if let total = self.totalCostUSD {
                Text("Total (30d): \(UsageFormatter.usdString(total))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private struct Model {
        let points: [Point]
        let pointsByDateKey: [String: Point]
        let entriesByDateKey: [String: DailyEntry]
        let dateKeys: [(key: String, date: Date)]
        let axisDates: [Date]
        let barColor: Color
        let peakKey: String?
        let maxCostUSD: Double
    }

    private static let selectionBandColor = Color(nsColor: .labelColor).opacity(0.1)

    private static func capHeight(maxValue: Double) -> Double {
        maxValue * 0.05
    }

    private static func makeModel(provider: UsageProvider, daily: [DailyEntry]) -> Model {
        self.makeModel(provider: provider, daily: daily, now: Date())
    }

    private static func makeModel(provider: UsageProvider, daily: [DailyEntry], now: Date) -> Model {
        let sorted = daily.sorted { lhs, rhs in lhs.date < rhs.date }

        var entriesByKey: [String: DailyEntry] = [:]
        entriesByKey.reserveCapacity(sorted.count)
        for entry in sorted {
            entriesByKey[entry.date] = entry
        }

        let dayRange = Self.rollingDayKeys(endingAt: now)

        var points: [Point] = []
        points.reserveCapacity(dayRange.count)

        var pointsByKey: [String: Point] = [:]
        pointsByKey.reserveCapacity(dayRange.count)

        var dateKeys: [(key: String, date: Date)] = []
        dateKeys.reserveCapacity(dayRange.count)

        var peak: (key: String, costUSD: Double)?
        var maxCostUSD: Double = 0

        for item in dayRange {
            let entry = entriesByKey[item.key]
            let costUSD = max(0, entry?.costUSD ?? 0)
            let point = Point(date: item.date, costUSD: costUSD, totalTokens: entry?.totalTokens)
            points.append(point)
            pointsByKey[item.key] = point
            dateKeys.append((item.key, item.date))
            if costUSD > 0 {
                if let cur = peak {
                    if costUSD > cur.costUSD { peak = (item.key, costUSD) }
                } else {
                    peak = (item.key, costUSD)
                }
                maxCostUSD = max(maxCostUSD, costUSD)
            }
        }

        let axisDates: [Date] = {
            guard let first = dateKeys.first?.date, let last = dateKeys.last?.date else { return [] }
            if Calendar.current.isDate(first, inSameDayAs: last) { return [first] }
            return [first, last]
        }()

        let barColor = Self.barColor(for: provider)
        return Model(
            points: points,
            pointsByDateKey: pointsByKey,
            entriesByDateKey: entriesByKey,
            dateKeys: dateKeys,
            axisDates: axisDates,
            barColor: barColor,
            peakKey: peak?.key,
            maxCostUSD: maxCostUSD)
    }

    private static func barColor(for provider: UsageProvider) -> Color {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private static func dateFromDayKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }

        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone.current
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return comps.date
    }

    private static func rollingDayKeys(endingAt now: Date) -> [(key: String, date: Date)] {
        var days: [(key: String, date: Date)] = []
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -29, to: end) ?? end
        var current = start

        while current <= end {
            let comps = calendar.dateComponents([.year, .month, .day], from: current)
            let key = String(format: "%04d-%02d-%02d", comps.year ?? 1970, comps.month ?? 1, comps.day ?? 1)
            let date = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: current) ?? current
            days.append((key, date))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return days
    }

    private static func peakPoint(model: Model) -> Point? {
        guard let key = model.peakKey else { return nil }
        return model.pointsByDateKey[key]
    }

    private static func hasUsage(entry: DailyEntry) -> Bool {
        if let totalTokens = entry.totalTokens, totalTokens > 0 {
            return true
        }
        if (entry.inputTokens ?? 0) > 0
            || (entry.outputTokens ?? 0) > 0
            || (entry.cacheCreationTokens ?? 0) > 0
            || (entry.cacheReadTokens ?? 0) > 0
        {
            return true
        }
        return false
    }

    private func selectionBandRect(model: Model, proxy: ChartProxy, geo: GeometryProxy) -> CGRect? {
        guard let key = self.selectedDateKey else { return nil }
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geo[plotAnchor]
        guard let index = model.dateKeys.firstIndex(where: { $0.key == key }) else { return nil }
        let date = model.dateKeys[index].date
        guard let x = proxy.position(forX: date) else { return nil }

        func xForIndex(_ idx: Int) -> CGFloat? {
            guard idx >= 0, idx < model.dateKeys.count else { return nil }
            return proxy.position(forX: model.dateKeys[idx].date)
        }

        let xPrev = xForIndex(index - 1)
        let xNext = xForIndex(index + 1)

        let leftInPlot: CGFloat = if let xPrev {
            (xPrev + x) / 2
        } else if let xNext {
            x - (xNext - x) / 2
        } else {
            x - 8
        }

        let rightInPlot: CGFloat = if let xNext {
            (xNext + x) / 2
        } else if let xPrev {
            x + (x - xPrev) / 2
        } else {
            x + 8
        }

        let left = plotFrame.origin.x + min(leftInPlot, rightInPlot)
        let right = plotFrame.origin.x + max(leftInPlot, rightInPlot)
        return CGRect(x: left, y: plotFrame.origin.y, width: right - left, height: plotFrame.height)
    }

    private func updateSelection(
        location: CGPoint?,
        model: Model,
        proxy: ChartProxy,
        geo: GeometryProxy)
    {
        guard let location else {
            if self.selectedDateKey != nil { self.selectedDateKey = nil }
            return
        }

        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        guard plotFrame.contains(location) else { return }

        let xInPlot = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xInPlot) else { return }
        guard let nearest = self.nearestDateKey(to: date, model: model) else { return }

        if self.selectedDateKey != nearest {
            self.selectedDateKey = nearest
        }
    }

    private func nearestDateKey(to date: Date, model: Model) -> String? {
        guard !model.dateKeys.isEmpty else { return nil }
        var best: (key: String, distance: TimeInterval)?
        for entry in model.dateKeys {
            let dist = abs(entry.date.timeIntervalSince(date))
            if let cur = best {
                if dist < cur.distance { best = (entry.key, dist) }
            } else {
                best = (entry.key, dist)
            }
        }
        return best?.key
    }

    private func detailLines(model: Model) -> (primary: String, secondary: String?) {
        guard let key = self.selectedDateKey,
              let point = model.pointsByDateKey[key],
              let date = Self.dateFromDayKey(key)
        else {
            return ("Hover a bar for details", nil)
        }

        let dayLabel = date.formatted(.dateTime.month(.abbreviated).day())
        let primary = if let entry = model.entriesByDateKey[key], let costUSD = entry.costUSD, costUSD > 0 {
            "\(dayLabel): \(UsageFormatter.usdString(costUSD))"
        } else if let entry = model.entriesByDateKey[key], Self.hasUsage(entry: entry) {
            "\(dayLabel): No priced cost data"
        } else {
            "\(dayLabel): No cost data"
        }

        if let tokens = point.totalTokens {
            let withTokens = "\(primary) · \(UsageFormatter.tokenCountString(tokens)) tokens"
            let secondary = self.topModelsText(key: key, model: model)
            return (withTokens, secondary)
        }
        let secondary = self.topModelsText(key: key, model: model)
        return (primary, secondary)
    }

    private func topModelsText(key: String, model: Model) -> String? {
        guard let entry = model.entriesByDateKey[key] else { return nil }
        guard let breakdown = entry.modelBreakdowns, !breakdown.isEmpty else { return nil }
        let parts = breakdown
            .compactMap { item -> (name: String, costUSD: Double)? in
                guard let costUSD = item.costUSD, costUSD > 0 else { return nil }
                return (UsageFormatter.modelDisplayName(item.modelName), costUSD)
            }
            .sorted { lhs, rhs in
                if lhs.costUSD == rhs.costUSD { return lhs.name < rhs.name }
                return lhs.costUSD > rhs.costUSD
            }
            .prefix(3)
            .map { "\($0.name) \(UsageFormatter.usdString($0.costUSD))" }
        guard !parts.isEmpty else { return nil }
        return "Top: \(parts.joined(separator: " · "))"
    }
}

extension CostHistoryChartMenuView {
    enum TestSupport {
        struct DayState: Equatable {
            let dayKey: String
            let costUSD: Double
            let hasEntry: Bool
        }

        @MainActor
        static func makeDayStates(
            provider: UsageProvider = .codex,
            daily: [DailyEntry],
            now: Date) -> [DayState]
        {
            let model = CostHistoryChartMenuView.makeModel(provider: provider, daily: daily, now: now)
            return model.dateKeys.compactMap { item -> DayState? in
                guard let point = model.pointsByDateKey[item.key] else { return nil }
                return DayState(
                    dayKey: item.key,
                    costUSD: point.costUSD,
                    hasEntry: model.entriesByDateKey[item.key] != nil)
            }
        }
    }
}
