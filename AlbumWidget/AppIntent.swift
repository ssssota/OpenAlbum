// Copyright (C) 2025 TOMIKAWA Sotaro
// https://github.com/ssssota/OpenAlbum

import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Configuration" }
  static var description: IntentDescription { "Album." }

  // Parameter to set the update interval
  @Parameter(title: "Update Interval", default: .min60)
  var updateIntervalMinutes: UpdateInterval

  enum UpdateInterval: Int, AppEnum {
    case min5 = 5
    case min20 = 15
    case min30 = 30
    case min60 = 60
    case hour3 = 180
    case hour6 = 360
    case hour12 = 720
    case day1 = 1440

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
      .init(name: "Update Interval")
    }

    static var caseDisplayRepresentations:
      [ConfigurationAppIntent.UpdateInterval: DisplayRepresentation]
    {
      [
        .min5: "5 Minutes",
        .min20: "15 Minutes",
        .min30: "30 Minutes",
        .min60: "1 Hour",
        .hour3: "3 Hours",
        .hour6: "6 Hours",
        .hour12: "12 Hours",
        .day1: "1 Day",
      ]
    }

  }
}
