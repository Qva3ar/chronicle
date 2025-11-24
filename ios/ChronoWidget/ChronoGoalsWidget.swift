import WidgetKit
import SwiftUI

struct GoalsProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalsEntry {
        GoalsEntry(date: Date(), goalsCount: 0, primaryGoal: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalsEntry) -> ()) {
        let entry = GoalsEntry(date: Date(), goalsCount: 0, primaryGoal: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Read widget data from UserDefaults (shared with Flutter app)
        let userDefaults = UserDefaults(suiteName: "group.com.aturdi.chrono.widget")
        let goalsCount = userDefaults?.integer(forKey: "goals_count") ?? 0
        let goalsDataString = userDefaults?.string(forKey: "goals_data") ?? "[]"

        var primaryGoal: GoalData? = nil
        if let data = goalsDataString.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstGoal = jsonArray.first {
            if let id = firstGoal["id"] as? Int,
               let title = firstGoal["title"] as? String,
               let progress = firstGoal["progress"] as? Int,
               let timeSpent = firstGoal["timeSpent"] as? String,
               let goalTime = firstGoal["goalTime"] as? String {
                let isRunning = firstGoal["isRunning"] as? Bool ?? false
                primaryGoal = GoalData(id: id, title: title, progress: progress, timeSpent: timeSpent, goalTime: goalTime, isRunning: isRunning)
            }
        }

        let entry = GoalsEntry(
            date: Date(),
            goalsCount: goalsCount,
            primaryGoal: primaryGoal
        )

        // Refresh every 30 seconds if a goal is running, otherwise every 5 minutes
        let refreshInterval = primaryGoal?.isRunning == true ? 30 : 300
        let nextUpdate = Calendar.current.date(byAdding: .second, value: refreshInterval, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct GoalData {
    let id: Int
    let title: String
    let progress: Int
    let timeSpent: String
    let goalTime: String
    let isRunning: Bool
}

struct GoalsEntry: TimelineEntry {
    let date: Date
    let goalsCount: Int
    let primaryGoal: GoalData?
}

struct GoalCardView: View {
    let goal: GoalData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title and Play Button
            HStack {
                Text(goal.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()

                // Play/Pause button
                Link(destination: URL(string: goal.isRunning ? "chrono://stop_goal?id=\(goal.id)" : "chrono://start_goal?id=\(goal.id)")!) {
                    Image(systemName: goal.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 1.0, green: 0.76, blue: 0.03))
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(white: 0.3))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(Color(red: 1.0, green: 0.76, blue: 0.03))
                        .frame(width: geometry.size.width * CGFloat(goal.progress) / 100.0, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)

            // Time Info
            HStack {
                Text(goal.timeSpent)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.8))
                Spacer()
                Text("/ \(goal.goalTime)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.8))
            }
        }
        .padding(10)
        .background(Color(white: 1.0, opacity: 0.1))
        .cornerRadius(8)
    }
}

struct ChronoGoalsWidgetEntryView : View {
    var entry: GoalsProvider.Entry

    var body: some View {
        ZStack {
            Color(red: 0.17, green: 0.17, blue: 0.17)

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("🎯")
                        .font(.system(size: 20))
                    Text("Goals")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }

                // Show up to 4 goals
                if let firstGoal = entry.primaryGoal {
                    // Goal Card
                    GoalCardView(goal: firstGoal)
                } else {
                    // No goals state
                    Text("No active goals")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }

                Spacer()

                // View All button
                Link(destination: URL(string: "chrono://open_goals")!) {
                    Text("View All Goals")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(red: 1.0, green: 0.76, blue: 0.03))
                        .cornerRadius(8)
                }
            }
            .padding(16)
        }
    }
}

@main
struct ChronoGoalsWidget: Widget {
    let kind: String = "ChronoGoalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoalsProvider()) { entry in
            ChronoGoalsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Chrono Goals")
        .description("Track your goal progress and start/stop timers")
        .supportedFamilies([.systemMedium])
    }
}

struct ChronoGoalsWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleGoal = GoalData(
            id: 1,
            title: "Learn Swift Programming",
            progress: 45,
            timeSpent: "01:23:45",
            goalTime: "3h 0m",
            isRunning: true
        )

        ChronoGoalsWidgetEntryView(entry: GoalsEntry(
            date: Date(),
            goalsCount: 3,
            primaryGoal: sampleGoal
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
