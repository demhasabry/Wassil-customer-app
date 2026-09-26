import ActivityKit
import WidgetKit
import SwiftUI

// Must be named EXACTLY this and declared here, in the widget extension's
// own target — NOT shared/imported from the live_activities plugin (which
// has its own internal copy it uses to start the activity). ActivityKit
// matches the app's Activity.request() to this widget's
// ActivityConfiguration by decoding across the process boundary, not by
// Swift's same-module type identity, so two independently-compiled but
// identically-shaped declarations is the documented, correct pattern for
// this plugin (github.com/istornz/live_activities).
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    public struct ContentState: Codable, Hashable {}
    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

// The actual content (status text, ETA, rider name) never travels through
// ActivityKit's ContentState at all — the plugin writes it into this shared
// App Group UserDefaults store instead, keyed by "{activityId}_{key}", and
// ContentState just carries a changing timestamp to trigger a re-render.
// Must match customer_app's live_activity_service.dart's appGroupId exactly.
private let sharedDefaults = UserDefaults(suiteName: "group.com.example.customerApp.liveactivity")

// Deliberately diagnostic, not a friendly default — this can only be seen by
// checking the phone directly (no Mac to pull device logs from), so if the
// read side ever fails again, the two failure modes need to be
// distinguishable from a screenshot alone: no App Groups entitlement at all
// (sharedDefaults nil) vs. entitlement present but this specific key never
// written (wrong/stale activity id, or the writer-side app never wrote it).
private func statusText(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
    guard let defaults = sharedDefaults else { return "No App Group access" }
    return defaults.string(forKey: context.attributes.prefixedKey("statusText"))
        ?? "No data (id \(context.attributes.id.uuidString.prefix(8)))"
}

private func etaText(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
    sharedDefaults?.string(forKey: context.attributes.prefixedKey("etaText")) ?? ""
}

private func riderName(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
    sharedDefaults?.string(forKey: context.attributes.prefixedKey("riderName")) ?? ""
}

struct DeliveryLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            DeliveryLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.orange)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !etaText(context).isEmpty {
                        Text(etaText(context))
                            .font(.headline)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusText(context))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if !riderName(context).isEmpty {
                            Text(riderName(context))
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
                if !etaText(context).isEmpty {
                    Text(etaText(context))
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
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText(context))
                    .font(.headline)
                let rider = riderName(context)
                if !rider.isEmpty {
                    Text(rider)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            let eta = etaText(context)
            if !eta.isEmpty {
                Text(eta)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(Color.white)
    }
}
