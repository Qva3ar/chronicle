import WidgetKit
import SwiftUI

struct RoutinesProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoutinesEntry {
        RoutinesEntry(date: Date(), routinesCount: 0, completedCount: 0, routines: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RoutinesEntry) -> ()) {
        let entry = RoutinesEntry(date: Date(), routinesCount: 0, completedCount: 0, routines: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Read widget data from UserDefaults (shared with Flutter app)
        let userDefaults = UserDefaults(suiteName: "group.com.aturdi.chrono.widget")
        let routinesCount = userDefaults?.integer(forKey: "routines_count") ?? 0
        let completedCount = userDefaults?.integer(forKey: "completed_count") ?? 0
        let routinesDataString = userDefaults?.string(forKey: "routines_data") ?? "[]"

        var routines: [RoutineData] = []
        if let data = routinesDataString.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            routines = jsonArray.prefix(5).compactMap { dict in
                guard let id = dict["id"] as? Int,
                      let name = dict["name"] as? String,
                      let time = dict["time"] as? String,
                      let isDone = dict["isDone"] as? Bool else {
                    return nil
                }
                let streak = dict["streak"] as? Int ?? 0
                let showStreak = dict["showStreak"] as? Bool ?? true
                return RoutineData(id: id, name: name, time: time, isDone: isDone, streak: streak, showStreak: showStreak)
            }
        }

        let entry = RoutinesEntry(
            date: Date(),
            routinesCount: routinesCount,
            completedCount: completedCount,
            routines: routines
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RoutineData {
    let id: Int
    let name: String
    let time: String
    let isDone: Bool
    let streak: Int
    let showStreak: Bool
}

struct RoutinesEntry: TimelineEntry {
    let date: Date
    let routinesCount: Int
    let completedCount: Int
    let routines: [RoutineData]
}

struct ChronoRoutinesWidgetEntryView : View {
    var entry: RoutinesProvider.Entry

    var body: some View {
        ZStack {
            Color(red: 0.17, green: 0.17, blue: 0.17)

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("✓")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 1.0, green: 0.76, blue: 0.03))
                    Text("Today's Routines")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(entry.completedCount)/\(entry.routinesCount)")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.8))
                }

                if entry.routines.isEmpty {
                    // No routines state
                    Text("No routines for today")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    // Routines list
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.routines.prefix(4), id: \.id) { routine in
                            HStack {
                                Text(routine.isDone ? "✓" : "○")
                                    .font(.system(size: 16))
                                    .foregroundColor(routine.isDone ? Color(red: 1.0, green: 0.76, blue: 0.03) : Color(white: 0.5))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    HStack(spacing: 4) {
                                        Text(routine.time)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(white: 0.7))

                                        if routine.showStreak && routine.streak > 0 {
                                            Text("🔥\(routine.streak)")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(red: 1.0, green: 0.76, blue: 0.03))
                                        }
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Spacer()

                // Open button
                Link(destination: URL(string: "chrono://open_routines")!) {
                    Text("Open Routines")
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
struct ChronoRoutinesWidget: Widget {
    let kind: String = "ChronoRoutinesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoutinesProvider()) { entry in
            ChronoRoutinesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Chrono Routines")
        .description("View and track your daily routines")
        .supportedFamilies([.systemMedium])
    }
}

struct ChronoRoutinesWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleRoutines = [
            RoutineData(id: 1, name: "Morning Prayer", time: "06:00", isDone: true, streak: 5, showStreak: true),
            RoutineData(id: 2, name: "Exercise", time: "07:00", isDone: false, streak: 3, showStreak: true),
            RoutineData(id: 3, name: "Read Quran", time: "08:00", isDone: false, streak: 0, showStreak: true)
        ]

        ChronoRoutinesWidgetEntryView(entry: RoutinesEntry(
            date: Date(),
            routinesCount: 5,
            completedCount: 1,
            routines: sampleRoutines
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
