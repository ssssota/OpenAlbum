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
  var timestamp: Date

  init(timestamp: Date) {
    self.timestamp = timestamp
  }
}
