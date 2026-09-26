import ActivityKit
import WidgetKit
import SwiftUI

// Must stay identical in shape to Runner's own copy in
// ios/Runner/LiveActivityChannel.swift — the two are independently-compiled
// targets with no shared framework between them, and ActivityKit matches
// Runner's Activity<DeliveryActivityAttributes>.request() to this widget's
// ActivityConfiguration by decoding the Codable payload across the process
// boundary, not by Swift's same-module type identity. The real content
// lives directly in ContentState — no App Group/shared UserDefaults
// involved, since registering a new App Group identifier turned out to
// require Apple's paid Developer Program.
//
// stepLabels/unit/unitShort live on the (immutable) attributes rather than
// ContentState — the delivery's language can't change mid-trip, and this
// keeps every live update's payload smaller. See
// design_handoff_wassil/LIVE-ACTIVITY-1c.md for the full spec this
// implements (option 1c).
struct DeliveryActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var etaText: String
        var riderName: String
        var vehicleText: String
        var plate: String
        var progress: Double
    }
    var requestId: String
    var stepLabels: [String]
    var unit: String
    var unitShort: String
}

extension DeliveryActivityAttributes {
    // Bounds-safe — an out-of-range index must never crash a widget process
    // over something as low-stakes as a missing label.
    func stepLabel(_ index: Int) -> String {
        guard index >= 0, index < stepLabels.count else { return "" }
        return stepLabels[index]
    }
}

// Hex values straight from the Wassil brand handoff
// (design_handoff_wassil/README.md's token table, plus
// LIVE-ACTIVITY-1c.md's own additions for this screen specifically) —
// duplicated here rather than imported because a widget extension is its
// own compiled target with no access to the main app's Dart-side theme
// constants, and the app doesn't yet have a native (Swift-side) design-token
// file of its own to share.
private extension Color {
    static let wassilPrimary = Color(red: 0x25 / 255, green: 0x51 / 255, blue: 0xCA / 255)
    static let wassilInkAlt = Color(red: 0x0B / 255, green: 0x12 / 255, blue: 0x20 / 255)
    static let wassilCompactPinTint = Color(red: 0x5C / 255, green: 0x82 / 255, blue: 0xDE / 255)
    static let wassilProgressGreen = Color(red: 0x4A / 255, green: 0xDE / 255, blue: 0x9B / 255)
}

// A capsule track (white 18%) with a proportional fill (progress green) —
// shared by the Lock Screen's two-segment bar and the expanded island's
// single full-width bar.
private struct ProgressTrack: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(Color.wassilProgressGreen)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 4)
    }
}

private struct ProgressDot: View {
    let reached: Bool

    var body: some View {
        Circle()
            .fill(reached ? Color.wassilProgressGreen : Color.clear)
            .overlay(
                Circle().stroke(reached ? Color.clear : Color.white.opacity(0.35), lineWidth: 1.5)
            )
            .frame(width: 10, height: 10)
    }
}

// compactTrailing's/minimal's progress ring — a stroked circle trimmed to
// `progress`, rotated so it starts at 12 o'clock rather than 3 o'clock.
private struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.20), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Color.wassilProgressGreen, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// The real Wassil pin (Assets.xcassets/WassilPin.imageset), rendered as a
// template image so a single asset serves both plain-white contexts (the
// Lock Screen tile) and tinted ones (the compact island) via
// .foregroundColor(). Below ~16pt the pin's inner hole fills in and it
// reads as a blob rather than a pin — callers below that size should use
// the systemName: "mappin" SF Symbol fallback instead (see `minimal` below).
private struct WassilPinImage: View {
    var body: some View {
        Image("WassilPin")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }
}

struct DeliveryLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryActivityAttributes.self) { context in
            DeliveryLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.wassilPrimary)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(context.state.riderName.prefix(1))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.riderName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if !context.state.plate.isEmpty {
                                Text(context.state.plate)
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.etaText.isEmpty {
                        VStack(spacing: 2) {
                            Text(context.state.etaText)
                                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(context.attributes.unit)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(context.state.statusText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        ProgressTrack(fraction: context.state.progress)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                WassilPinImage()
                    .frame(height: 18)
                    .foregroundColor(.wassilCompactPinTint)
            } compactTrailing: {
                // The compact pill has room for only a handful of
                // characters — lineLimit/fixedSize is a defensive backstop
                // so an unexpectedly long value degrades to truncation
                // instead of stretching the whole pill into an oversized
                // banner (the ring itself is a fixed 22×22 regardless).
                HStack(spacing: 6) {
                    ProgressRing(progress: context.state.progress, size: 22, lineWidth: 4)
                    if !context.state.etaText.isEmpty {
                        Text(context.state.etaText + context.attributes.unitShort)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            } minimal: {
                ZStack {
                    ProgressRing(progress: context.state.progress, size: 22, lineWidth: 4)
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.wassilCompactPinTint)
                }
            }
        }
    }
}

struct DeliveryLockScreenView: View {
    let attributes: DeliveryActivityAttributes
    let state: DeliveryActivityAttributes.ContentState

    private var subtitle: String {
        [state.riderName, state.vehicleText].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.wassilPrimary)
                    .frame(width: 34, height: 34)
                    .overlay(
                        WassilPinImage()
                            .frame(height: 19)
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.statusText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12.5))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if !state.etaText.isEmpty {
                    VStack(spacing: 2) {
                        Text(state.etaText)
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(attributes.unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            HStack(spacing: 6) {
                ProgressDot(reached: true)
                ProgressTrack(fraction: min(1, max(0, state.progress / 0.5)))
                ProgressDot(reached: state.progress >= 0.5)
                ProgressTrack(fraction: min(1, max(0, (state.progress - 0.5) / 0.5)))
                ProgressDot(reached: state.progress >= 1.0)
            }
            .padding(.top, 16)
            HStack {
                Text(attributes.stepLabel(0))
                Spacer()
                Text(attributes.stepLabel(1))
                Spacer()
                Text(attributes.stepLabel(2))
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .lineLimit(1)
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .activityBackgroundTint(Color.wassilInkAlt)
        .activitySystemActionForegroundColor(Color.white)
    }
}
