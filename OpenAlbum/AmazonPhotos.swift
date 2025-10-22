// Copyright (C) 2025 TOMIKAWA Sotaro
// https://github.com/ssssota/OpenAlbum

import Foundation
import SwiftData
import UIKit

struct AmazonPhotos: AlbumProvider {
  let id: String  // Share ID
  let tld: AmazonPhotosTLD
  init(id: String, tld: AmazonPhotosTLD) {
    self.id = id
    self.tld = tld
  }

  var url: String {
    "https://www.amazon\(tld.rawValue)/photos/share/\(id)"
  }

  private static var countCache: [String: Int] = [:]  // shareId -> count
  private static var metaCache: [String: AlbumMeta] = [:]  // shareId -> AlbumMeta
  private static var mediaParentCache: [String: String] = [:]  // shareId -> parentId
  private static var imageUrlCache: [String: String] = [:]  // itemId -> imageUrl
  private static let cacheQueue = DispatchQueue(
    label: "AmazonPhotosCacheQueue", attributes: .concurrent)

  private static let filters =
    "kind:FILE* AND contentProperties.contentType:\"image/jpeg\" AND status:(AVAILABLE*) AND settings.hidden:false"

  static func resolve(url: URL) -> (any AlbumProvider)? {
    guard let host = url.host, host.starts(with: "www.amazon.") else { return nil }
    let pathComponents = url.pathComponents
    guard pathComponents.count >= 4, pathComponents[1] == "photos", pathComponents[2] == "share"
    else { return nil }
    let shareId = pathComponents[3]
    // Extract TLD from host ("www.amazon" + rest)
    let tldPart = host.replacingOccurrences(of: "www.amazon", with: "")
    guard let tld = AmazonPhotosTLD(rawValue: tldPart) else { return nil }
    return AmazonPhotos(id: shareId, tld: tld)
  }

  func count() async throws -> Int {
    if let cached = AmazonPhotos.countCache[id] {
      return cached
    }

    guard let mediaParentId = try await resolveMediaParent() else { return 0 }

    let response = try await fetchChildren(
      nodeId: mediaParentId,
      limit: 1,  // 0 is not allowed
      offset: 0,
      filters: Self.filters,
      searchOnFamily: true,
      lowResThumbnail: true)
    AmazonPhotos.cacheQueue.async(flags: .barrier) {
      AmazonPhotos.countCache[id] = response.count
    }
    return response.count
  }

  func random() async throws -> UIImage? {
    let url = try await randomUrl()
    guard let url else { return nil }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw AmazonPhotosError.badStatus(code: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }
    return UIImage(data: data)
  }

  private func randomUrl() async throws -> URL? {
    let count = try await self.count()
    guard count > 0 else { return nil }
    let idx = Int.random(in: 0..<count)

    if let cachedUrlString = AmazonPhotos.imageUrlCache["\(id)[\(idx)]"],
      let cachedUrl = URL(string: cachedUrlString)
    {
      return cachedUrl
    }

    guard let mediaParentId = try await resolveMediaParent() else { return nil }
    let response = try await fetchChildren(
      nodeId: mediaParentId,
      limit: 1,
      offset: idx,
      filters: Self.filters,
      tempLink: true,
      searchOnFamily: true,
      lowResThumbnail: true)
    guard let urlString = response.data.first?.tempLink,
      var url = URL(string: urlString)
    else { return nil }
    let areaMax = 988_574.0
    let sizeMax = Int(sqrt(areaMax))
    url.append(queryItems: [.init(name: "viewBox", value: "\(sizeMax),\(sizeMax)")])
    AmazonPhotos.cacheQueue.async(flags: .barrier) {
      Self.imageUrlCache["\(id)[\(idx)]"] = url.absoluteString
    }
    return url
  }

  private struct ShareMetadata: Decodable {
    struct NodeInfo: Decodable {
      let createdDate: String
      let id: String
      let modifiedDate: String
      let name: String
    }
    let nodeInfo: NodeInfo
    let shareId: String
  }

  private struct ChildrenResponse: Decodable {
    struct Item: Decodable {
      let id: String
      let kind: String
      let tempLink: String?
    }
    let count: Int
    let data: [Item]
  }

  private func resolveMediaParent() async throws -> String? {
    if let cached = Self.mediaParentCache[id] {
      return cached
    }
    let shareMeta = try await fetchShareMetadata()
    guard let parentId = try await fetchMediaParentId(from: shareMeta.collectionId) else {
      return nil
    }
    AmazonPhotos.cacheQueue.async(flags: .barrier) {
      Self.mediaParentCache[id] = parentId
    }
    return parentId
  }

  private func fetchShareMetadata() async throws -> (name: String, collectionId: String) {
    let base = "https://www.amazon\(tld.rawValue)/drive/v1/shares/\(id)"
    guard var components = URLComponents(string: base) else { throw AmazonPhotosError.invalidURL }
    components.queryItems = [
      URLQueryItem(name: "shareId", value: id),
      URLQueryItem(name: "resourceVersion", value: "V2"),
      URLQueryItem(name: "ContentType", value: "JSON"),
      URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000))),
    ]
    guard let url = components.url else { throw AmazonPhotosError.invalidURL }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      // print("Response: \(response)")
      throw AmazonPhotosError.badStatus(code: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }
    let decoder = JSONDecoder()
    let share: ShareMetadata
    do {
      share = try decoder.decode(ShareMetadata.self, from: data)
    } catch {
      // print("Decoding error: \(error)")
      throw AmazonPhotosError.decoding(error)
    }
    return (name: share.nodeInfo.name, collectionId: share.nodeInfo.id)
  }

  private func fetchMediaParentId(from collectionId: String) async throws -> String? {
    let firstResp = try await fetchChildren(nodeId: collectionId, limit: 1)
    let firstItem = firstResp.data.first
    if let item = firstItem, item.kind == "FILE" { return collectionId }
    if let item = firstItem { return item.id }
    return nil
  }

  private func fetchMediaCount(collectionId: String) async throws -> Int {
    let mediaParentId = try await fetchMediaParentId(from: collectionId)
    guard let mediaParentId else { return 0 }
    let resp = try await fetchChildren(
      nodeId: mediaParentId,
      limit: 1,
      filters:
        "kind:FILE* AND contentProperties.contentType:(image* OR video*) AND status:(AVAILABLE*) AND settings.hidden:false"
    )
    return resp.count
  }

  @discardableResult
  private func fetchChildren(
    nodeId: String,
    limit: Int,
    offset: Int = 0,
    filters: String? = nil,
    sort: String? = nil,
    tempLink: Bool = false,
    searchOnFamily: Bool = false,
    lowResThumbnail: Bool = false
  ) async throws -> ChildrenResponse {
    var components = URLComponents(
      string: "https://www.amazon\(tld.rawValue)/drive/v1/nodes/\(nodeId)/children")!
    var query: [URLQueryItem] = [
      URLQueryItem(name: "asset", value: "ALL"),
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "offset", value: String(offset)),
      URLQueryItem(name: "resourceVersion", value: "V2"),
      URLQueryItem(name: "ContentType", value: "JSON"),
      URLQueryItem(name: "shareId", value: id),
      URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000))),
    ]
    if let filters { query.append(URLQueryItem(name: "filters", value: filters)) }
    if let sort { query.append(URLQueryItem(name: "sort", value: sort)) }
    if tempLink { query.append(URLQueryItem(name: "tempLink", value: "true")) }
    if searchOnFamily { query.append(URLQueryItem(name: "searchOnFamily", value: "true")) }
    if lowResThumbnail { query.append(URLQueryItem(name: "lowResThumbnail", value: "true")) }
    components.queryItems = query
    let url = components.url!
    // print("Fetching children: \(url)")
    let (data, response) = try await URLSession.shared.data(from: url)
    // print("Fetched \(data.count) bytes")
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      // print("Response: \(response)")
      throw AmazonPhotosError.badStatus(code: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }
    let decoder = JSONDecoder()
    do {
      return try decoder.decode(ChildrenResponse.self, from: data)
    } catch {
      // print("Decoding error: \(error)")
      throw AmazonPhotosError.decoding(error)
    }
  }
}

enum AmazonPhotosTLD: String, CaseIterable, Codable, Hashable {
  case us = ".com"
  case uk = ".co.uk"
  case ca = ".ca"
  case de = ".de"
  case fr = ".fr"
  case es = ".es"
  case jp = ".co.jp"
}

// MARK: - Error Definitions
enum AmazonPhotosError: LocalizedError, CustomNSError, Equatable {
  static func == (lhs: AmazonPhotosError, rhs: AmazonPhotosError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidURL, .invalidURL): return true
    case (.badStatus(let a), .badStatus(let b)): return a == b
    case (.decoding, .decoding): return true
    case (.network(let a), .network(let b)): return a.code == b.code
    case (.unknown, .unknown): return true
    default: return false
    }
  }
  case invalidURL
  case badStatus(code: Int)
  case decoding(Error)
  case network(URLError)
  case unknown(Error)

  static var errorDomain: String { "AmazonPhotosError" }
  var errorCode: Int {
    switch self {
    case .invalidURL: return 1001
    case .badStatus(let code): return 1002 + code
    case .decoding: return 1003
    case .network(let err): return Int(err.errorCode)
    case .unknown: return 1099
    }
  }
  var errorDescription: String? {
    switch self {
    case .invalidURL: return "Amazon Photos: Invalid URL constructed."
    case .badStatus(let code): return "Amazon Photos: Server responded with status code \(code)."
    case .decoding(let err):
      return "Amazon Photos: Failed to decode server response (\(err.localizedDescription))."
    case .network(let err): return "Amazon Photos: Network error (\(err.localizedDescription))."
    case .unknown(let err): return "Amazon Photos: Unknown error (\(err.localizedDescription))."
    }
  }
}
