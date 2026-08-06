import WidgetKit
import SwiftUI

@main
struct ChronoWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChronoWidget()
        ChronoGoalsWidget()
        ChronoRoutinesWidget()
        ChronoTimerLiveActivity()
    }
}
