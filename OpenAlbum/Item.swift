// Copyright (C) 2025 TOMIKAWA Sotaro
// https://github.com/ssssota/OpenAlbum

import Foundation
import SwiftData
import UIKit

enum ItemMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] = [ItemSchemaV001.self]
  static var stages: [MigrationStage] = []
}

typealias Item = ItemSchemaV001.Item
struct ItemSchemaV001: VersionedSchema {
  static var models: [any PersistentModel.Type] = [Item.self]
  static var versionIdentifier: Schema.Version = .init(0, 1, 3)

  @Model
  final class Item: Sendable {
    @Attribute(.unique)
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

  func random(item: Item) async -> AlbumImage? {
    guard let provider = resolveProvider(url: item.url) else { return nil }
    return try? await provider.randomImage()
  }

  func resolveImage(url: URL, id: String) async -> URL? {
    guard let provider = resolveProvider(url: url) else { return nil }
    return try? await provider.image(id: id)
  }
}

protocol AlbumProvider {
  static func resolve(url: URL) -> AlbumProvider?
  func count() async throws -> Int
  func randomImage() async throws -> AlbumImage?
  func image(id: String) async throws -> URL?
}

struct AlbumMeta {
  let id: String
  let name: String
  let count: Int
}

struct AlbumImage {
  let image: UIImage
  let id: any LosslessStringConvertible
}
