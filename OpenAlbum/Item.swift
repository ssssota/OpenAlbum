//
//  Item.swift
//  OpenAlbum
//
//  Created by Tomikawa Sotaro on 2025/10/09.
//

import Foundation
import SwiftData
import UIKit

enum ItemMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] = [
    ItemSchemaV001.self,
    ItemSchemaV002.self,
  ]
  static var stages: [MigrationStage] = [
    stageV1ToV2
  ]

  static let stageV1ToV2 = MigrationStage.custom(
    fromVersion: ItemSchemaV001.self, toVersion: ItemSchemaV002.self, willMigrate: nil
  ) { context in
    let descriptor = FetchDescriptor<ItemSchemaV001.Item>(predicate: nil)
    let items = try context.fetch(descriptor)
    for oldItem in items {
      let newItem = ItemSchemaV002.Item(url: oldItem.url, count: nil)
      context.insert(newItem)
      context.delete(oldItem)
    }
    try? context.save()
  }
}

typealias Item = ItemSchemaV002.Item

struct ItemSchemaV001: VersionedSchema {
  static var models: [any PersistentModel.Type] = [Item.self]

  static var versionIdentifier: Schema.Version = .init(0, 0, 1)

  @Model
  final class Item: Sendable {
    @Attribute(.unique)
    var url: URL
    var id: ItemID

    init(url: URL, id: ItemID) {
      self.url = url
      self.id = id
    }
  }

  enum ItemID: Codable, Hashable {
    case int(Int)
    case string(String)
    case none

    func toString() -> String {
      switch self {
      case .int(let value):
        return String(value)
      case .string(let value):
        return value
      case .none:
        return "none"
      }
    }
  }

}

struct ItemSchemaV002: VersionedSchema {
  static var models: [any PersistentModel.Type] = [Item.self]
  static var versionIdentifier: Schema.Version = .init(0, 1, 0)

  @Model
  final class Item: Sendable {
    var url: URL
    var count: Int?

    init(url: URL, count: Int? = nil) {
      self.url = url
      self.count = count
    }
  }
}

class AlbumManager {
  static let shared = AlbumManager(providers: [
    AmazonPhotos.self,
    JustImage.self,
  ])
  private init(providers: [AlbumProvider.Type]) {
    self.providers = providers
  }
  private let providers: [AlbumProvider.Type]
  private var providerMap: [String: any AlbumProvider] = [:]

  func available(url: URL) -> Bool {
    return resolveProvider(url: url) != nil
  }

  private func resolveProvider(url: URL) -> AlbumProvider? {
    if let existing = providerMap[url.absoluteString] {
      return existing
    }
    for provider in providers {
      if let p = provider.resolve(url: url) {
        providerMap[url.absoluteString] = p
        return p
      }
    }
    return nil
  }

  func count(item: Item) async -> Int? {
    if let count = item.count {
      return count
    }
    guard
      let provider = resolveProvider(url: item.url),
      let count = try? await provider.count()
    else { return nil }
    item.count = count
    return count
  }

  func random(item: Item) async -> UIImage? {
    guard
      let provider = resolveProvider(url: item.url),
      let image = try? await provider.random()
    else { return nil }
    return image
  }
}

protocol AlbumProvider {
  static func resolve(url: URL) -> AlbumProvider?
  func count() async throws -> Int
  func random() async throws -> UIImage?
}

struct AlbumMeta {
  let id: String
  let name: String
  let count: Int
}
