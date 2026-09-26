import ActivityKit
import Flutter

// Bypasses the `live_activities` plugin's App-Group/UserDefaults-based
// content delivery entirely — that needs an App Groups entitlement, and
// registering a NEW App Group identifier on this project's free Apple ID
// hit "This resource is only for developers enrolled in a developer
// program" on developer.apple.com. ActivityKit's own ContentState sync
// between this app and the DeliveryWidget extension process needs no such
// entitlement, so this talks to it directly from a plain MethodChannel.
//
// DeliveryActivityAttributes below MUST stay identical in shape to the
// widget extension's own copy in
// ios/DeliveryWidget/DeliveryLiveActivityWidget.swift — see that file's own
// comment for why two independently-compiled copies is the correct,
// documented pattern here.
@available(iOS 16.1, *)
struct DeliveryActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
        var etaText: String
        var riderName: String
    }
    var requestId: String
}

enum LiveActivityChannel {
    static func register(with registry: FlutterPluginRegistry) {
        guard let registrar = registry.registrar(forPlugin: "LiveActivityChannel") else { return }
        let channel = FlutterMethodChannel(
            name: "com.example.customerApp/liveActivity",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            guard #available(iOS 16.1, *) else {
                result(nil)
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let requestId = args["requestId"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "requestId is required", details: nil))
                return
            }

            switch call.method {
            case "startOrUpdate":
                let state = DeliveryActivityAttributes.ContentState(
                    statusText: args["statusText"] as? String ?? "",
                    etaText: args["etaText"] as? String ?? "",
                    riderName: args["riderName"] as? String ?? ""
                )
                Task {
                    await startOrUpdate(requestId: requestId, state: state)
                    result(nil)
                }
            case "end":
                Task {
                    await end(requestId: requestId)
                    result(nil)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    @available(iOS 16.1, *)
    @MainActor
    private static func startOrUpdate(requestId: String, state: DeliveryActivityAttributes.ContentState) async {
        if let existing = Activity<DeliveryActivityAttributes>.activities.first(where: { $0.attributes.requestId == requestId }) {
            if #available(iOS 16.2, *) {
                await existing.update(ActivityContent(state: state, staleDate: nil))
            } else {
                await existing.update(using: state)
            }
            return
        }
        do {
            if #available(iOS 16.2, *) {
                _ = try Activity<DeliveryActivityAttributes>.request(
                    attributes: DeliveryActivityAttributes(requestId: requestId),
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } else {
                _ = try Activity<DeliveryActivityAttributes>.request(
                    attributes: DeliveryActivityAttributes(requestId: requestId),
                    contentState: state,
                    pushType: nil
                )
            }
        } catch {
            // Best-effort — matches LiveActivityService's own swallow-and-move-on
            // approach on the Dart side (see that file's doc comment).
        }
    }

    @available(iOS 16.1, *)
    @MainActor
    private static func end(requestId: String) async {
        guard let activity = Activity<DeliveryActivityAttributes>.activities.first(where: { $0.attributes.requestId == requestId }) else {
            return
        }
        await activity.end(dismissalPolicy: .immediate)
    }
}
