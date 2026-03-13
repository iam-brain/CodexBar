import Charts
import CodexBarCore
import SwiftUI

@MainActor
struct CostHistoryChartMenuView: View {
    typealias DailyEntry = CostUsageDailyReport.Entry

    struct Point: Identifiable {
        let id: String
        let date: Date
        let displayCostUSD: Double
        let actualCostUSD: Double?
        let totalTokens: Int?

        init(date: Date, displayCostUSD: Double, actualCostUSD: Double?, totalTokens: Int?) {
            self.date = date
            self.displayCostUSD = displayCostUSD
            self.actualCostUSD = actualCostUSD
            self.totalTokens = totalTokens
            self.id = "\(Int(date.timeIntervalSince1970))-\(displayCostUSD)"
        }
    }

    struct DetailModelLine: Identifiable {
        let id: String
        let text: String
        let title: String
        let subtitle: String?
        let accentColor: Color
    }

    struct DetailContent {
        let primary: String
        let models: [DetailModelLine]
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
                            y: .value("Cost", point.displayCostUSD))
                            .foregroundStyle(model.barColor)
                    }
                    if let peak = Self.peakPoint(model: model) {
                        let peakCostUSD = peak.actualCostUSD ?? 0
                        let capStart = max(peakCostUSD - Self.capHeight(maxValue: model.maxCostUSD), 0)
                        BarMark(
                            x: .value("Day", peak.date, unit: .day),
                            yStart: .value("Cap start", capStart),
                            yEnd: .value("Cap end", peakCostUSD))
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

                let detail = Self.detailContent(selectedDateKey: self.selectedDateKey, model: model)
                VStack(alignment: .leading, spacing: Self.detailSpacing) {
                    Text(detail.primary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: Self.detailPrimaryLineHeight, alignment: .leading)
                    ForEach(detail.models) { row in
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle()
                                .fill(row.accentColor)
                                .frame(width: 2, height: row.subtitle == nil ? 14 : Self.detailRowHeight)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                if let subtitle = row.subtitle {
                                    Text(subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                        .frame(height: Self.detailRowHeight, alignment: .leading)
                    }
                    ForEach(0..<max(model.maxDetailLineCount - detail.models.count, 0), id: \.self) { _ in
                        Text(" ")
                            .font(.caption)
                            .frame(height: Self.detailRowHeight, alignment: .leading)
                            .opacity(0)
                    }
                }
                .frame(
                    height: Self.detailBlockHeight(maxBreakdownRows: model.maxDetailLineCount),
                    alignment: .topLeading)
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

    struct Model {
        let points: [Point]
        let pointsByDateKey: [String: Point]
        let entriesByDateKey: [String: DailyEntry]
        let dateKeys: [(key: String, date: Date)]
        let axisDates: [Date]
        let barColor: Color
        let peakKey: String?
        let maxCostUSD: Double
        let maxDetailLineCount: Int
    }

    private static let selectionBandColor = Color(nsColor: .labelColor).opacity(0.1)
    private static let maxVisibleDetailLines = 4
    private static let detailPrimaryLineHeight: CGFloat = 16
    private static let detailRowHeight: CGFloat = 24
    private static let detailSpacing: CGFloat = 6

    private static func capHeight(maxValue: Double) -> Double {
        maxValue * 0.05
    }

    static func makeModel(provider: UsageProvider, daily: [DailyEntry]) -> Model {
        let sorted = daily.sorted { lhs, rhs in lhs.date < rhs.date }
        var entriesByKey: [String: DailyEntry] = [:]
        entriesByKey.reserveCapacity(sorted.count)
        for entry in sorted {
            entriesByKey[entry.date] = entry
        }

        var points: [Point] = []
        points.reserveCapacity(sorted.count)

        var pointsByKey: [String: Point] = [:]
        pointsByKey.reserveCapacity(sorted.count)

        var dateKeys: [(key: String, date: Date)] = []
        dateKeys.reserveCapacity(sorted.count)

        var peak: (key: String, costUSD: Double)?
        var maxCostUSD: Double = 0
        for entry in sorted {
            if let displayCostUSD = Self.displayCostUSD(for: entry), displayCostUSD > 0 {
                maxCostUSD = max(maxCostUSD, displayCostUSD)
            }
        }

        var maxDetailLineCount = 0
        for entry in sorted {
            maxDetailLineCount = max(maxDetailLineCount, Self.renderedBreakdownRowCount(for: entry))
            guard let displayCostUSD = Self.displayCostUSD(for: entry) else { continue }
            guard let date = self.dateFromDayKey(entry.date) else { continue }
            let point = Point(
                date: date,
                displayCostUSD: displayCostUSD,
                actualCostUSD: entry.costUSD,
                totalTokens: entry.totalTokens)
            points.append(point)
            pointsByKey[entry.date] = point
            dateKeys.append((entry.date, date))
            if displayCostUSD > 0 {
                if let cur = peak {
                    if displayCostUSD > cur.costUSD { peak = (entry.date, displayCostUSD) }
                } else {
                    peak = (entry.date, displayCostUSD)
                }
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
            maxCostUSD: maxCostUSD,
            maxDetailLineCount: maxDetailLineCount)
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

    private static func peakPoint(model: Model) -> Point? {
        guard let key = model.peakKey else { return nil }
        return model.pointsByDateKey[key]
    }

    private static func renderedBreakdownRowCount(for entry: DailyEntry) -> Int {
        guard let breakdown = entry.modelBreakdowns, !breakdown.isEmpty else { return 0 }
        if breakdown.count > self.maxVisibleDetailLines {
            return self.maxVisibleDetailLines
        }
        return breakdown.count
    }

    private static func detailBlockHeight(maxBreakdownRows: Int) -> CGFloat {
        guard maxBreakdownRows > 0 else { return self.detailPrimaryLineHeight }
        return self.detailPrimaryLineHeight +
            (CGFloat(maxBreakdownRows) * self.detailRowHeight) +
            (CGFloat(maxBreakdownRows) * self.detailSpacing)
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

    static func detailContent(selectedDateKey: String?, model: Model) -> DetailContent {
        guard let key = selectedDateKey,
              let point = model.pointsByDateKey[key],
              let date = self.dateFromDayKey(key)
        else {
            return DetailContent(primary: "Hover a bar for details", models: [])
        }

        let dayLabel = date.formatted(.dateTime.month(.abbreviated).day())
        let partial = Self.hasUnpricedModels(key: key, model: model) ? " partial" : ""
        let primary = if let actualCostUSD = point.actualCostUSD, actualCostUSD > 0 {
            "\(dayLabel): \(UsageFormatter.usdString(actualCostUSD))\(partial)"
        } else if point.displayCostUSD > 0 {
            "\(dayLabel): \(UsageFormatter.usdString(point.displayCostUSD))\(partial)"
        } else if point.totalTokens ?? 0 > 0 {
            "\(dayLabel): No priced cost data"
        } else {
            "\(dayLabel): No cost data"
        }

        let primaryWithTokens = if let tokens = point.totalTokens {
            "\(primary) · \(UsageFormatter.tokenCountString(tokens)) tokens"
        } else {
            primary
        }
        return DetailContent(
            primary: primaryWithTokens,
            models: Self.detailModelLines(key: key, model: model))
    }

    private static func hasUnpricedModels(key: String, model: Model) -> Bool {
        guard let entry = model.entriesByDateKey[key],
              let breakdown = entry.modelBreakdowns
        else {
            return false
        }
        return breakdown.contains { $0.costUSD == nil }
    }

    private static func displayCostUSD(for entry: DailyEntry) -> Double? {
        if let actualCostUSD = entry.costUSD, actualCostUSD > 0 {
            return actualCostUSD
        }
        guard let breakdown = entry.modelBreakdowns else { return nil }
        let subtotal = breakdown.reduce(0.0) { partial, item in
            partial + max(0, item.costUSD ?? 0)
        }
        if subtotal > 0 {
            return subtotal
        }
        return (entry.totalTokens ?? 0) > 0 ? 0 : nil
    }

    private static func detailModelLines(key: String, model: Model) -> [DetailModelLine] {
        guard let entry = model.entriesByDateKey[key] else { return [] }
        guard let breakdown = entry.modelBreakdowns, !breakdown.isEmpty else { return [] }

        let sorted = breakdown
            .sorted { lhs, rhs in
                let lCost = lhs.costUSD ?? -1
                let rCost = rhs.costUSD ?? -1
                if lCost != rCost { return lCost > rCost }
                let lTokens = lhs.totalTokens ?? -1
                let rTokens = rhs.totalTokens ?? -1
                if lTokens != rTokens { return lTokens > rTokens }
                return lhs.modelName < rhs.modelName
            }

        let visibleLimit = sorted.count > Self.maxVisibleDetailLines
            ? (Self.maxVisibleDetailLines - 1)
            : sorted.count
        let visible = Array(sorted.prefix(visibleLimit))
        var rows = visible.enumerated().map { index, item in
            let title = Self.detailModelDisplayName(item.modelName)
            let subtitle = Self.breakdownValueText(
                costUSD: item.costUSD,
                totalTokens: item.totalTokens,
                includeUnpricedLabel: item.costUSD == nil)
            return DetailModelLine(
                id: "\(item.modelName)-\(index)",
                text: Self.detailLineText(title: title, costUSD: item.costUSD, totalTokens: item.totalTokens),
                title: title,
                subtitle: subtitle,
                accentColor: model.barColor.opacity(Self.breakdownAccentOpacity(for: index)))
        }

        let hidden = Array(sorted.dropFirst(visibleLimit))
        if !hidden.isEmpty {
            let hiddenCost = hidden.reduce(0.0) { partial, item in
                partial + (item.costUSD ?? 0)
            }
            let hiddenTokens = hidden.reduce(0) { partial, item in
                partial + (item.totalTokens ?? 0)
            }
            let overflowTitle = hidden.count == 1 ? "1 more model" : "\(hidden.count) more models"
            rows.append(DetailModelLine(
                id: "overflow",
                text: overflowTitle,
                title: overflowTitle,
                subtitle: Self.breakdownValueText(
                    costUSD: hiddenCost > 0 ? hiddenCost : nil,
                    totalTokens: hiddenTokens > 0 ? hiddenTokens : nil),
                accentColor: Color(nsColor: .tertiaryLabelColor).opacity(0.55)))
        }

        return rows
    }

    private static func breakdownAccentOpacity(for index: Int) -> Double {
        let opacity = 0.75 - (Double(index) * 0.12)
        return max(0.3, opacity)
    }

    private static func detailLineText(title: String, costUSD: Double?, totalTokens: Int?) -> String {
        let tokensText = totalTokens.map { " · \(UsageFormatter.tokenCountString($0)) tokens" } ?? ""
        if let costUSD, costUSD > 0 {
            return "\(title): \(UsageFormatter.usdString(costUSD))\(tokensText)"
        }
        return "\(title): unpriced\(tokensText)"
    }

    private static func detailModelDisplayName(_ raw: String) -> String {
        let cleaned = UsageFormatter.modelDisplayName(raw)
        let lower = cleaned.lowercased()
        if lower == "unknown" {
            return "Unknown model"
        }
        guard lower.hasPrefix("gpt-") else {
            return cleaned
        }

        let remainder = lower.dropFirst("gpt-".count)
        let parts = remainder.split(separator: "-", omittingEmptySubsequences: true)
        guard let version = parts.first else {
            return cleaned
        }
        let suffix = parts.dropFirst().map { part in
            String(part.prefix(1)).uppercased() + String(part.dropFirst())
        }
        guard !suffix.isEmpty else {
            return "GPT-\(version)"
        }
        return "GPT-\(version) \(suffix.joined(separator: " "))"
    }

    private static func breakdownValueText(
        costUSD: Double?,
        totalTokens: Int?,
        includeUnpricedLabel: Bool = false) -> String?
    {
        var parts: [String] = []
        if let costUSD, costUSD > 0 {
            parts.append(UsageFormatter.usdString(costUSD))
        } else if includeUnpricedLabel {
            parts.append("unpriced")
        }
        if let totalTokens, totalTokens > 0 {
            parts.append("\(UsageFormatter.tokenCountString(totalTokens)) tokens")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
