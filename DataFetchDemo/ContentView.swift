//
//  ContentView.swift
//  DataFetchDemo
//
//

import SwiftUI

struct ContentView: View {
  let dataFetcher: DataFetcher

  struct ListItem: Identifiable {
    let data: Data
    let color: Color

    init(data: Data, color: Color) {
      self.data = data
      self.color = color
    }

    var id: String {
      data.id
    }
  }

  @State private var dataList: [ListItem] = []
  @State private var hasPrefetched = false
  @State private var isLoading = false
  @State private var currentColor = Color.green

  var body: some View {
    List {
      if hasPrefetched {
        Text("Has prefetched!!")
          .foregroundStyle(.red)
      }

      ForEach(dataList) { item in
        Text(item.data.payload)
          .foregroundStyle(item.color)
      }

      if isLoading {
        ProgressView()
      }

      Button {
        Task {
          currentColor = generateRandomColor()

          isLoading = true
          let stream = await dataFetcher.makeFetchStream(.pagination)
          for await chunk in stream {
            dataList.append(ListItem(data: chunk, color: currentColor))
          }
          isLoading = false
        }
      } label: {
        Text("Load More")
      }
    }
    .padding()
    .task {
      log("Task begin")
      isLoading = true

      var stream = await dataFetcher.prefetchedStream
      log("After prefetchedStream")
      if stream != nil {
        hasPrefetched = true
      } else {
        stream = await dataFetcher.makeFetchStream(.initial)
      }

      for await chunk in stream! {
        log("Chunk received")
        dataList.append(ListItem(data: chunk, color: chunk.type == .cache ? .purple : currentColor))
      }

      log("Streaming ended")
      isLoading = false
    }
  }

  private func log(_ str: String) {
    print("DataFetcherUI: \(str) - (is main thread? \(Thread.current.isMainThread))")
  }

  private func generateRandomColor() -> Color {
    // Generate random values for red, green, and blue components
    let red = Double.random(in: 0...1)
    let green = Double.random(in: 0...1)
    let blue = Double.random(in: 0...1)

    // Return a Color with the random values
    return Color(red: red, green: green, blue: blue)
  }
}
