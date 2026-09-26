import ActivityKit
import WidgetKit
import SwiftUI

// Must stay identical in shape to Runner's own copy in
// ios/Runner/LiveActivityChannel.swift — the two are independently-compiled
// targets with no shared framework between them, and ActivityKit matches
// Runner's Activity<DeliveryActivityAttributes>.request() to this widget's
// ActivityConfiguration by decoding the Codable payload across the process
// boundary, not by Swift's same-module type identity. Unlike an earlier
// version of this file, the real content lives directly in ContentState —
// no App Group/shared UserDefaults involved, since registering a new App
// Group identifier turned out to require Apple's paid Developer Program.
struct DeliveryActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var etaText: String
        var riderName: String
    }
    var requestId: String
}

// Hex values straight from the Wassil brand handoff
// (design_handoff_wassil/README.md's token table) — `primary` and `inkAlt`
// specifically, since this widget lives only in customer_app (the rider app
// uses `accent` as its own primary instead). Duplicated here rather than
// imported because a widget extension is its own compiled target with no
// access to the main app's Dart-side theme constants, and the app doesn't
// yet have a native (Swift-side) design-token file of its own to share.
private extension Color {
    static let wassilPrimary = Color(red: 0x25 / 255, green: 0x51 / 255, blue: 0xCA / 255)
    static let wassilInkAlt = Color(red: 0x0B / 255, green: 0x12 / 255, blue: 0x20 / 255)
}

struct DeliveryLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryActivityAttributes.self) { context in
            DeliveryLockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    // Closest SF Symbol match to the actual Wassil mark (a
                    // white pin on a filled circle) — a real bundled logo
                    // image is a bigger lift (needs its own asset catalog
                    // wired into the widget extension target, which
                    // ios/add_widget_extension.rb doesn't set up yet) and
                    // this reads as on-brand at the tiny sizes this actually
                    // renders at.
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.wassilPrimary)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.etaText.isEmpty {
                        Text(context.state.etaText)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.statusText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if !context.state.riderName.isEmpty {
                            Text(context.state.riderName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.wassilPrimary)
            } compactTrailing: {
                // The compact pill has room for only a handful of characters
                // (this is what forced etaText's own content to be shortened
                // at the source — see liveActivityEtaMinutes's ARB comment)
                // — lineLimit/fixedSize here is a second line of defense so
                // an unexpectedly long value degrades to truncation instead
                // of stretching the whole pill into an oversized banner.
                if !context.state.etaText.isEmpty {
                    Text(context.state.etaText)
                        .font(.caption2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            } minimal: {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.wassilPrimary)
            }
        }
    }
}

struct DeliveryLockScreenView: View {
    let state: DeliveryActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundColor(.wassilPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.statusText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                if !state.riderName.isEmpty {
                    Text(state.riderName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            Spacer()
            if !state.etaText.isEmpty {
                Text(state.etaText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding()
        .activityBackgroundTint(Color.wassilInkAlt)
        .activitySystemActionForegroundColor(Color.white)
    }
}
