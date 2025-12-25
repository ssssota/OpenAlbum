// Copyright (C) 2025 TOMIKAWA Sotaro
// https://github.com/ssssota/OpenAlbum

import Foundation
import SwiftData
import UIKit

struct JustImage: AlbumProvider {
  let url: URL
  init(url: URL) {
    self.url = url
  }

  private static let validExtensions = [
    "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif",
  ]

  static func resolve(url: URL) -> (any AlbumProvider)? {
    if validExtensions.contains(url.pathExtension.lowercased()) {
      return JustImage(url: url)
    }
    return nil
  }

  func count() async throws -> Int {
    return 1
  }

  func randomImage() async throws -> AlbumImage? {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode)
    else {
      return nil
    }
    guard let image = UIImage(data: data) else { return nil }
    return AlbumImage(image: image, id: 0)
  }

  func image(id: String) async throws -> URL? {
    return url
  }
}
