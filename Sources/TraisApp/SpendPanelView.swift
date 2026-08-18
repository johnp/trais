import AppKit
import Charts
import SwiftUI
import TraisCore

struct SpendPanelView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var model: AppModel
    @State private var verticalZoom = 0.85

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.samples.count > 1 {
                Chart(model.samples) { sample in
                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        yStart: .value("Visible baseline", yDomain.lowerBound),
                        yEnd: .value("Spend", sample.chartValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.28), .accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Spend", sample.chartValue)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(Color.accentColor)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisTick()
                            .foregroundStyle(.secondary)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                if spansMultipleDays {
                                    Text(date, format: .dateTime.weekday(.abbreviated).day())
                                } else {
                                    Text(date, format: .dateTime.hour().minute())
                                }
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisTick()
                            .foregroundStyle(.secondary)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(
                                    amount.formattedCurrency(
                                        model.displayCurrency,
                                        maximumFractionDigits: yAxisFractionDigits
                                    )
                                )
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ChartZoomOverlay { delta in
                            adjustZoom(by: delta)
                        }

                        if showsYAxisBreak, let plotFrame = proxy.plotFrame {
                            AxisBreakMark()
                                .position(
                                    x: geometry[plotFrame].minX,
                                    y: geometry[plotFrame].maxY - 4
                                )
                        }
                    }
                }
                .frame(height: 142)
                .help("Scroll to zoom the spend axis")
                .accessibilityLabel("AI spend over the last seven days")
                .accessibilityHint("Scroll over the chart to zoom the spend axis")
            } else {
                ContentUnavailableView(
                    "Waiting for history",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("The graph appears after two updates.")
                )
                .frame(height: 112)
            }

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshing)

                Spacer()

                Button {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit trais", systemImage: "power")
                }
            }
            .labelStyle(.iconOnly)
        }
        .padding(16)
        .frame(width: 360)
    }

    private var yDomain: ClosedRange<Double> {
        let values = model.samples.map(\.chartValue)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...1
        }

        let spread = maximum - minimum
        let tightPadding = max(spread * 0.2, 0.005)
        let tightLower = max(0, minimum - tightPadding)
        let tightUpper = maximum + tightPadding
        let fullUpper = max(maximum * 1.05, maximum + 0.01, 0.01)
        let fullScaleWeight = pow(1 - verticalZoom, 3)
        let lower = tightLower * (1 - fullScaleWeight)
        let upper = tightUpper + (fullUpper - tightUpper) * fullScaleWeight

        return lower...max(upper, lower + 0.01)
    }

    private var yAxisFractionDigits: Int {
        yDomain.upperBound - yDomain.lowerBound < 0.05 ? 3 : 2
    }

    private var showsYAxisBreak: Bool {
        yDomain.lowerBound > 0.000_1
    }

    private func adjustZoom(by delta: CGFloat) {
        guard delta != 0 else { return }
        let amount = min(max(abs(delta) * 0.015, 0.03), 0.15)
        let direction = delta > 0 ? amount : -amount
        withAnimation(.easeOut(duration: 0.12)) {
            verticalZoom = min(max(verticalZoom + direction, 0), 1)
        }
    }

    private var spansMultipleDays: Bool {
        guard let first = model.samples.first, let last = model.samples.last else {
            return false
        }
        return !Calendar.current.isDate(first.timestamp, inSameDayAs: last.timestamp)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("AI Spend")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if model.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(model.currentSpendText)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                spendSummary(model.sevenDaySpendText, period: "past 7 days")
                spendSummary(model.todaySpendText, period: "today")
            }
            .padding(.bottom, 3)
        }
    }

    private func spendSummary(_ amount: String, period: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(amount)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(period)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .contentTransition(.numericText())
    }
}
