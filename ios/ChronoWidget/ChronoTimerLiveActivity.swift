import ActivityKit
import WidgetKit
import SwiftUI

// Mirror of the attributes declared inside the live_activities plugin
// (LiveActivitiesPlugin.swift). The field layout must match exactly so
// ActivityKit can decode the activity in the widget-extension process.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        var appGroupId: String
    }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

private let sharedDefault = UserDefaults(suiteName: "group.com.aturdi.chrono.widget")!
private let chronoAccent = Color(red: 1.0, green: 0.76, blue: 0.03)

// Values written by LiveActivityService (Dart) through the shared app group.
private struct SessionData {
    let goalTitle: String
    let sessionRange: ClosedRange<Date>
    let totalSpentSeconds: Int
    let goalTargetSeconds: Int

    init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
        goalTitle = sharedDefault.string(
            forKey: context.attributes.prefixedKey("goalTitle")) ?? "Chrono"
        let startMs = sharedDefault.double(
            forKey: context.attributes.prefixedKey("sessionStartMs"))
        let endMs = sharedDefault.double(
            forKey: context.attributes.prefixedKey("sessionEndMs"))
        let start = Date(timeIntervalSince1970: startMs / 1000)
        var end = Date(timeIntervalSince1970: endMs / 1000)
        if end <= start { end = start.addingTimeInterval(60) }
        sessionRange = start...end
        totalSpentSeconds = sharedDefault.integer(
            forKey: context.attributes.prefixedKey("totalSpentSeconds"))
        goalTargetSeconds = sharedDefault.integer(
            forKey: context.attributes.prefixedKey("goalTargetSeconds"))
    }

    var goalProgressText: String {
        let remaining = max(goalTargetSeconds - totalSpentSeconds, 0)
        return "Total \(Self.format(totalSpentSeconds)) of \(Self.format(goalTargetSeconds)) · \(Self.format(remaining)) left"
    }

    static func format(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

struct ChronoTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock screen / banner
            let data = SessionData(context: context)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("🎯 \(data.goalTitle)")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    // Ticks down natively - no updates from the app needed.
                    Text(timerInterval: data.sessionRange, countsDown: true)
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .foregroundColor(chronoAccent)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                // Auto-animating session progress bar.
                ProgressView(timerInterval: data.sessionRange, countsDown: false)
                    .tint(chronoAccent)
                    .labelsHidden()
                Text(data.goalProgressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.17, green: 0.17, blue: 0.17))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let data = SessionData(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("🎯 \(data.goalTitle)")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: data.sessionRange, countsDown: true)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundColor(chronoAccent)
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(timerInterval: data.sessionRange, countsDown: false)
                            .tint(chronoAccent)
                            .labelsHidden()
                        Text(data.goalProgressText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(chronoAccent)
            } compactTrailing: {
                Text(timerInterval: data.sessionRange, countsDown: true)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(chronoAccent)
                    .frame(maxWidth: 60)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(chronoAccent)
            }
        }
    }
}
