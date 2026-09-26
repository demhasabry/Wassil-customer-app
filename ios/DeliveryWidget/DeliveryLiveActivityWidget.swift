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

struct DeliveryLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryActivityAttributes.self) { context in
            DeliveryLockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.orange)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.etaText.isEmpty {
                        Text(context.state.etaText)
                            .font(.headline)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.statusText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if !context.state.riderName.isEmpty {
                            Text(context.state.riderName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                if !context.state.etaText.isEmpty {
                    Text(context.state.etaText)
                        .font(.caption2)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

struct DeliveryLockScreenView: View {
    let state: DeliveryActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.statusText)
                    .font(.headline)
                if !state.riderName.isEmpty {
                    Text(state.riderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if !state.etaText.isEmpty {
                Text(state.etaText)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(Color.white)
    }
}
