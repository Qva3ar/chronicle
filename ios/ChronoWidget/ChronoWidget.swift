import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), title: "Chrono", body: "No insights yet", hasInsight: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), title: "Chrono", body: "No insights yet", hasInsight: false)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Read widget data from UserDefaults (shared with Flutter app)
        let userDefaults = UserDefaults(suiteName: "group.com.aturdi.chrono.widget")
        let hasInsight = userDefaults?.bool(forKey: "has_insight") ?? false
        let title = userDefaults?.string(forKey: "insight_title") ?? "Chrono"
        let body = userDefaults?.string(forKey: "insight_body") ?? "No insights yet"

        let entry = SimpleEntry(
            date: Date(),
            title: title,
            body: body,
            hasInsight: hasInsight
        )

        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String
    let body: String
    let hasInsight: Bool
}

struct ChronoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color(red: 0.17, green: 0.17, blue: 0.17)

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.hasInsight ? entry.title : "Chrono")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                Link(destination: URL(string: "chrono://create_note")!) {
                    Text("+ Note")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(red: 1.0, green: 0.76, blue: 0.03))
                        .cornerRadius(8)
                }
            }
            .padding(12)
        }
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color(red: 0.17, green: 0.17, blue: 0.17)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("💡")
                        .font(.system(size: 18))
                    Text(entry.hasInsight ? entry.title : "Chrono")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                }

                Text(entry.body)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.8))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                HStack {
                    Spacer()
                    Link(destination: URL(string: "chrono://create_note")!) {
                        Text("+ Note")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 1.0, green: 0.76, blue: 0.03))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color(red: 0.17, green: 0.17, blue: 0.17)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("💡")
                        .font(.system(size: 24))
                    Text("Chrono Insights")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }

                Text(entry.hasInsight ? entry.title : "Chrono")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(entry.body)
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.8))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                HStack {
                    Spacer()
                    if entry.hasInsight {
                        Link(destination: URL(string: "chrono://open_insight")!) {
                            Text("View")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(red: 1.0, green: 0.76, blue: 0.03))
                                .cornerRadius(8)
                        }
                    }
                    Link(destination: URL(string: "chrono://create_note")!) {
                        Text("+ Note")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(red: 1.0, green: 0.76, blue: 0.03))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(20)
        }
    }
}

@main
struct ChronoWidget: Widget {
    let kind: String = "ChronoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ChronoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Chrono Insights")
        .description("View your latest insights and quickly create notes")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ChronoWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChronoWidgetEntryView(entry: SimpleEntry(date: Date(), title: "Focus on your goals", body: "Spend 25 minutes on Quran reading to make progress today.", hasInsight: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            ChronoWidgetEntryView(entry: SimpleEntry(date: Date(), title: "Focus on your goals", body: "Spend 25 minutes on Quran reading to make progress today.", hasInsight: true))
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            ChronoWidgetEntryView(entry: SimpleEntry(date: Date(), title: "Focus on your goals", body: "Spend 25 minutes on Quran reading to make progress today. You've completed 3 out of 5 routines today - keep up the momentum!", hasInsight: true))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
