// Copyright (C) 2025 TOMIKAWA Sotaro
// https://github.com/ssssota/OpenAlbum

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
    .init(date: Date(), image: nil)
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry
  {
    let modelContext = ModelContext(modelContainer)
    guard let items = try? modelContext.fetch(FetchDescriptor<Item>()) else {
      return .init(date: Date(), image: nil)
    }
    var sumOfImages = 0
    var itemImages: [Item: Int] = [:]
    for item in items {
      let count = (await AlbumManager.shared.count(item: item)) ?? 0
      itemImages[item] = count
      sumOfImages += count
    }
    let randomIndex = Int.random(in: 0..<sumOfImages)
    var target: Item? = nil
    var cumulative = 0
    for (item, count) in itemImages {
      cumulative += count
      if randomIndex < cumulative + count {
        target = item
        break
      }
    }
    guard let target else {
      return .init(date: Date(), image: nil)
    }

    let image = await AlbumManager.shared.random(item: target)
    return SimpleEntry(date: Date(), image: image)
  }

  func timeline(
    for configuration: ConfigurationAppIntent,
    in context: Context
  ) async -> Timeline<SimpleEntry> {
    let entry = await snapshot(for: configuration, in: context)
    // if image is nil, update quickly
    let timeInterval =
      entry.image == nil ? 60 : TimeInterval(configuration.updateIntervalMinutes.rawValue * 60)
    return Timeline(
      entries: [entry],
      policy: .after(Date().addingTimeInterval(timeInterval)))
  }

  //    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
  //        // Generate a list containing the contexts this widget is relevant in.
  //    }
}

struct SimpleEntry: TimelineEntry {
  let date: Date

  let image: UIImage?
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
      kind: kind,
      provider: Provider(modelContainer: modelContainer)
    ) {
      entry in
      AlbumWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .contentMarginsDisabled()
  }
}

#Preview(as: .systemSmall) {
  AlbumWidget()
} timeline: {
  SimpleEntry(
    date: .now,
    image: UIImage(
      data: try! Data(
        contentsOf: URL(
          string:
            "https://fastly.picsum.photos/id/572/500/500.jpg?hmac=fg8DuZ9XdkpT4xivkrIW8N2hhvZK9YeWuKkPOeK0YUw"
        )!)))
}
