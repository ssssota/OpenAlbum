import Foundation
import SwiftData

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

  func items() async throws -> [ItemID] {
    return [.none]
  }

  func image(id: ItemID) async throws -> URL? {
    return url
  }
}
