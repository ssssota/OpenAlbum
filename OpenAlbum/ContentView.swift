//
//  ContentView.swift
//  OpenAlbum
//
//  Created by Tomikawa Sotaro on 2025/10/09.
//

import SwiftData
import SwiftUI
import WidgetKit

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]
  @State private var showModal = false

  var itemURLs: [URL] {
    return Array(Set(items.map { $0.url }))
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(itemURLs, id: \.self) { url in
          NavigationLink {
            Text(url.absoluteString)
          } label: {
            Text(url.absoluteString)
          }
        }
        .onDelete(perform: deleteItems)
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
        ToolbarItem {
          Button(action: {
            showModal = true
          }) {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
    }
    .sheet(isPresented: $showModal) {
      SheetView(
        onDismiss: {
          showModal = false
        },
        onAdd: { url in
          Task {
            let items = try? await AlbumManager.shared.items(url: url)
            items?.forEach { item in
              modelContext.insert(item)
            }
          }
          showModal = false
        }
      )
    }
  }

  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(items[index])
      }
    }
    // syncModel()
  }

  private func syncModel() {
    try? modelContext.save()
    // Widget の記録更新
    WidgetCenter.shared.reloadAllTimelines()
  }
}

struct SheetView: View {
  let onDismiss: (() -> Void)?
  let onAdd: ((URL) -> Void)?

  @State private var urlString: String = ""

  private var url: URL? {
    return URL(string: urlString)
  }
  private var available: Bool {
    guard let url = url else { return false }
    return AlbumManager.shared.available(url: url)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Album URL")) {
          TextField("URL", text: $urlString)
            .autocapitalization(.none)
            .keyboardType(.URL)
        }
      }
      .navigationTitle("Add New Item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onDismiss?()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            if let url {
              onAdd?(url)
            }
          }
          .bold()
          .disabled(!available)
        }
      }
    }
  }
}

enum LoadState {
  case idle
  case loading
  case loaded
  case failed
}

#Preview {
  ContentView()
    .modelContainer(for: Item.self, inMemory: true)
}
