// Copyright (C) 2025 TOMIKAWA Sotaro
// https://github.com/ssssota/OpenAlbum

import SwiftData
import SwiftUI
import WidgetKit

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]
  @State private var showModal = false
  @State private var tappedImage: TappedImage?

  var body: some View {
    NavigationStack {
      List {
        ForEach(items, id: \.self) { item in

          // NavigationLink {
          //   AlbumView(url: url)
          // } label: {
          Text("\(item.url.absoluteString) \(item.count != nil ? "(\(item.count!))" : "")")
          // }
        }
        .onDelete(perform: { indexSet in
          withAnimation {
            indexSet.map { items[$0] }.forEach { item in
              modelContext.delete(item)
            }
          }
          syncModel()
        })
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
          let item = Item(url: url)
          withAnimation {
            modelContext.insert(item)
          }
          showModal = false
          syncModel()
          Task {
            item.count = await AlbumManager.shared.count(item: item)
          }
        }
      )
    }
    .sheet(item: $tappedImage) { image in
      ImageViewer(url: image.url)
    }
    .onOpenURL { url in
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      guard components?.scheme == "openalbum",
        components?.host == "image",
        let queryItems = components?.queryItems,
        let urlString = queryItems.first(where: { $0.name == "url" })?.value,
        let url = URL(string: urlString),
        let id = queryItems.first(where: { $0.name == "id" })?.value
      else {
        return
      }
      Task {
        guard let resolvedUrl = await AlbumManager.shared.resolveImage(url: url, id: id) else { return }
        tappedImage = TappedImage(url: resolvedUrl)
      }
    }
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
          Text(
            "Enter the URL of the album you want to add. Currently, only URLs from Amazon Photos or just image URLs are supported."
          )
          .font(.caption)
          .foregroundColor(.secondary)
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

struct TappedImage: Identifiable {
  let url: URL
  var id: String { url.absoluteString }
}

struct ImageViewer: View {
  let url: URL
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .tint(.white)
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          case .failure:
            VStack(spacing: 12) {
              Text("Failed to load image")
                .foregroundColor(.white)
              Link("Open in browser", destination: url)
            }
            .padding()
          @unknown default:
            EmptyView()
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }
      }
    }
  }
}

// struct AlbumView: View {
//   @Environment(\.modelContext) private var modelContext
//   @Query private var items: [Item]
//   let url: URL

//   var albumItems: [Item] {
//     items.filter { $0.url == url }
//   }

//   var body: some View {
//     NavigationStack {
//       List {
//         ForEach(albumItems, id: \.self) { item in
//           NavigationLink {
//             ItemView(item: item)
//           } label: {
//             Text(item.id.toString())
//           }
//         }
//       }
//     }
//   }
// }

// struct ItemView: View {
//   let item: Item
//   @StateObject private var viewModel = ItemViewModel()

//   var body: some View {
//     VStack {
//       switch viewModel.loadState {
//       case .idle:
//         Color.clear
//           .task {
//             await viewModel.loadImage(item: item)
//           }
//       case .loading:
//         ProgressView()
//       case .loaded:
//         if let imageURL = viewModel.imageURL {
//           AsyncImage(url: imageURL) { phase in
//             switch phase {
//             case .empty:
//               ProgressView()
//             case .success(let image):
//               image
//                 .resizable()
//                 .scaledToFit()
//             case .failure:
//               VStack(spacing: 8) {
//                 Text("Failed to load image")
//                   .font(.headline)
//                 Button("Retry") {
//                   Task { await viewModel.retry(item: item) }
//                 }
//                 .buttonStyle(.borderedProminent)
//               }
//             @unknown default:
//               EmptyView()
//             }
//           }
//         } else {
//           Text("Loaded but no image URL")
//         }
//       case .failed(let error):
//         VStack(spacing: 8) {
//           Text("Failed to load image")
//             .font(.headline)
//           if let error {
//             Text(error.localizedDescription)
//               .font(.caption)
//               .foregroundColor(.secondary)
//               .multilineTextAlignment(.center)
//           }
//           Button("Retry") {
//             Task { await viewModel.retry(item: item) }
//           }
//           .buttonStyle(.borderedProminent)
//         }
//       }
//     }
//     .navigationTitle(item.id.toString())
//     .navigationBarTitleDisplayMode(.inline)
//   }
// }
// class ItemViewModel: ObservableObject {
//   @Published var imageURL: URL?
//   @Published var loadState: LoadState = .idle

//   struct NoImageError: LocalizedError {
//     var errorDescription: String? { "Image URL wasn’t returned." }
//   }

//   @MainActor
//   func loadImage(item: Item) async {
//     guard case .idle = loadState else { return }
//     loadState = .loading
//     do {
//       if let url = try await AlbumManager.shared.image(item: item) {
//         imageURL = url
//         loadState = .loaded
//       } else {
//         loadState = .failed(NoImageError())
//       }
//     } catch {
//       loadState = .failed(error)
//     }
//   }

//   @MainActor
//   func retry(item: Item) async {
//     imageURL = nil
//     loadState = .idle
//     await loadImage(item: item)
//   }
// }

// enum LoadState {
//   case idle
//   case loading
//   case loaded
//   case failed(Error?)
// }

#Preview {
  ContentView()
    .modelContainer(for: Item.self, inMemory: true)
}
