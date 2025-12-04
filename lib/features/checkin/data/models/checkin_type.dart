/// Type of checkin (morning or evening)
enum CheckinType {
  /// Morning checkin
  morning,

  /// Evening checkin
  evening,
}

/// Extension methods for CheckinType
extension CheckinTypeExtension on CheckinType {
  /// Get human-readable display name
  String get displayName {
    switch (this) {
      case CheckinType.morning:
        return 'Утренний чекин';
      case CheckinType.evening:
        return 'Вечерний чекин';
    }
  }

  /// Get short display name
  String get shortName {
    switch (this) {
      case CheckinType.morning:
        return 'Утренний';
      case CheckinType.evening:
        return 'Вечерний';
    }
  }
}
