//
//  Item.swift
//  OpenAlbum
//
//  Created by Tomikawa Sotaro on 2025/10/09.
//

import Foundation
import SwiftData

@Model
final class Item {
  var url: URL
  var id: String

  init(url: URL, id: String) {
    self.url = url
    self.id = id
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

  func items(url: URL) async throws -> [Item] {
    guard let provider = resolveProvider(url: url) else {
      fatalError("Provider not found for URL: \(url)")
    }
    let ids = try await provider.items()
    return ids.map { Item(url: url, id: $0) }
  }

  func image(item: Item) async throws -> URL? {
    guard let provider = resolveProvider(url: item.url) else {
      fatalError("Provider not found for URL: \(item.url)")
    }
    return try await provider.image(id: item.id)
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
}

protocol AlbumProvider {
  static func resolve(url: URL) -> AlbumProvider?
  func items() async throws -> [String]
  func image(id: String) async throws -> URL?
}

struct AlbumMeta {
  let id: String
  let name: String
  let count: Int
}
