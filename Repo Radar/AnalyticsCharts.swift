//
//  AnalyticsCharts.swift
//  Repo Radar
//
//  Created by Claude on 30/09/2025.
//

import SwiftUI

// MARK: - Line Chart
struct LineChart: View {
    let data: [Double]
    let color: Color
    let title: String?
    let showGrid: Bool

    init(data: [Double], color: Color = .blue, title: String? = nil, showGrid: Bool = true) {
        self.data = data
        self.color = color
        self.title = title
        self.showGrid = showGrid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack {
                    if showGrid {
                        GridLines()
                    }

                    if data.count > 1 {
                        LineShape(data: data)
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .animation(.easeInOut(duration: 0.5), value: data)

                        // Data points
                        ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                            Circle()
                                .fill(color)
                                .frame(width: 4, height: 4)
                                .position(
                                    x: CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width,
                                    y: geometry.size.height - (value / (data.max() ?? 1)) * geometry.size.height * 0.9 - geometry.size.height * 0.05
                                )
                        }
                    }
                }
            }
            .frame(height: 120)
        }
    }
}

// MARK: - Bar Chart
struct BarChart: View {
    let data: [Double]
    let colors: [Color]
    let title: String?
    let showValues: Bool

    init(data: [Double], colors: [Color]? = nil, title: String? = nil, showValues: Bool = true) {
        self.data = data
        self.colors = colors ?? Array(repeating: .blue, count: data.count)
        self.title = title
        self.showValues = showValues
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        VStack {
                            if showValues {
                                Text("\(Int(value))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Rectangle()
                                .fill(colors[index % colors.count])
                                .frame(
                                    width: (geometry.size.width - CGFloat(data.count - 1) * 4) / CGFloat(data.count),
                                    height: value > 0 ? (value / (data.max() ?? 1)) * geometry.size.height * 0.8 : 0
                                )
                                .animation(.easeInOut(duration: 0.5), value: data)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 100)
        }
    }
}

// MARK: - Progress Ring
struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    let title: String?
    let value: String?

    init(progress: Double, color: Color = .blue, title: String? = nil, value: String? = nil) {
        self.progress = max(0, min(1, progress))
        self.color = color
        self.title = title
        self.value = value
    }

    var body: some View {
        VStack(spacing: 4) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                if let value = value {
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .frame(width: 60, height: 60)
        }
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let change: String?
    let trend: Trend?
    let color: Color

    enum Trend {
        case up, down, neutral

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }

        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }
    }

    init(title: String, value: String, change: String? = nil, trend: Trend? = nil, color: Color = .blue) {
        self.title = title
        self.value = value
        self.change = change
        self.trend = trend
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 8) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                if let change = change, let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.icon)
                            .font(.caption2)
                            .foregroundColor(trend.color)

                        Text(change)
                            .font(.caption)
                            .foregroundColor(trend.color)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Helper Shapes
struct LineShape: Shape {
    let data: [Double]

    func path(in rect: CGRect) -> Path {
        guard data.count > 1 else { return Path() }

        let maxValue = data.max() ?? 1
        let minValue = data.min() ?? 0
        let range = maxValue - minValue

        var path = Path()
        let stepX = rect.width / CGFloat(data.count - 1)

        path.move(
            to: CGPoint(
                x: 0,
                y: rect.height - ((data[0] - minValue) / range) * rect.height * 0.9 - rect.height * 0.05
            )
        )

        for i in 1..<data.count {
            path.addLine(
                to: CGPoint(
                    x: CGFloat(i) * stepX,
                    y: rect.height - ((data[i] - minValue) / range) * rect.height * 0.9 - rect.height * 0.05
                )
            )
        }

        return path
    }
}

struct GridLines: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Horizontal lines
                for i in 0...4 {
                    let y = CGFloat(i) * geometry.size.height / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }

                // Vertical lines
                for i in 0...4 {
                    let x = CGFloat(i) * geometry.size.width / 4
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
            }
            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        }
    }
}

// MARK: - Previews
#Preview {
    VStack(spacing: 20) {
        LineChart(
            data: [10, 25, 15, 40, 30, 45, 35],
            color: .blue,
            title: "Star Growth"
        )

        BarChart(
            data: [20, 35, 15, 40, 25],
            colors: [.blue, .green, .orange, .red, .purple],
            title: "Weekly Activity"
        )

        HStack {
            ProgressRing(progress: 0.75, color: .green, title: "Health", value: "75%")
            ProgressRing(progress: 0.45, color: .orange, title: "Issues", value: "45%")
        }

        HStack {
            MetricCard(
                title: "Total Stars",
                value: "1,234",
                change: "+45",
                trend: .up,
                color: .blue
            )

            MetricCard(
                title: "Issues",
                value: "23",
                change: "-3",
                trend: .down,
                color: .red
            )
        }
    }
    .padding()
    .frame(width: 400)
}