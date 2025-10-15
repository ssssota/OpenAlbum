//
//  AlbumWidget.swift
//  AlbumWidget
//
//  Created by Tomikawa Sotaro on 2025/10/09.
//

import SwiftData
import SwiftUI
import UIKit
import WidgetKit

import struct WidgetKit.WidgetPreviewContext

struct Provider: AppIntentTimelineProvider {
  private let modelContainer: ModelContainer
  init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
  }

  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry.withConfiguration(configuration: ConfigurationAppIntent())
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry
  {
    let areaMax = 988_574.0
    let sizeMax = Int(sqrt(areaMax))
    let modelContext = ModelContext(modelContainer)
    guard let items = try? modelContext.fetch(FetchDescriptor<Item>()) else {
      return SimpleEntry.withConfiguration(configuration: configuration)
    }
    print("items: \(items)")
    guard let item = items.randomElement() else {
      return SimpleEntry.withConfiguration(configuration: configuration)
    }
    print("item: \(item)")
    guard var imageUrl = try? await AlbumManager.shared.image(item: item) else {
      return SimpleEntry.withConfiguration(configuration: configuration)
    }
    imageUrl.append(queryItems: [.init(name: "viewBox", value: "\(sizeMax),\(sizeMax)")])
    print("imageUrl with query: \(imageUrl)")
    guard let (data, _) = try? await URLSession.shared.data(from: imageUrl) else {
      return SimpleEntry.withConfiguration(configuration: configuration)
    }
    print("imageData")
    guard let image = UIImage(data: data) else {
      return SimpleEntry.withConfiguration(configuration: configuration)
    }

    return SimpleEntry(
      date: Date(),
      configuration: configuration,
      image: image
    )
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
    SimpleEntry
  > {
    return Timeline(
      entries: [await snapshot(for: configuration, in: context)],
      policy: .after(Date().addingTimeInterval(60 * 60)))
  }

  //    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
  //        // Generate a list containing the contexts this widget is relevant in.
  //    }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationAppIntent

  let image: UIImage?

  static func withConfiguration(configuration: ConfigurationAppIntent) -> SimpleEntry {
    SimpleEntry(
      date: Date(),
      configuration: configuration,
      image: nil)
  }
}

struct AlbumWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    if let uiImage = entry.image {
      Image(uiImage: uiImage)
        .resizable()
        .scaledToFill()
        .clipped()
    } else {

      Image("placeholder")
    }
  }
}

struct AlbumWidget: Widget {
  let kind: String = "AlbumWidget"
  private let modelContainer: ModelContainer = {
    let schema = Schema([Item.self])
    let configuration = ModelConfiguration(schema: schema)
    return try! ModelContainer(for: schema, configurations: [configuration])
  }()

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind, intent: ConfigurationAppIntent.self,
      provider: Provider(modelContainer: modelContainer)
    ) {
      entry in
      AlbumWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .contentMarginsDisabled()
  }
}

extension ConfigurationAppIntent {
  fileprivate static var smiley: ConfigurationAppIntent {
    let intent = ConfigurationAppIntent()
    intent.favoriteEmoji = "😀"
    return intent
  }

  fileprivate static var starEyes: ConfigurationAppIntent {
    let intent = ConfigurationAppIntent()
    intent.favoriteEmoji = "🤩"
    return intent
  }
}

#Preview(as: .systemSmall) {
  AlbumWidget()
} timeline: {
  SimpleEntry(
    date: .now, configuration: .smiley,
    image: UIImage(
      data: try! Data(
        contentsOf: URL(
          string:
            "https://fastly.picsum.photos/id/572/500/500.jpg?hmac=fg8DuZ9XdkpT4xivkrIW8N2hhvZK9YeWuKkPOeK0YUw"
        )!)))
}
