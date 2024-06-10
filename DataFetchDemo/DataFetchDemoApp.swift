//
//  DataFetchDemoApp.swift
//  DataFetchDemo
//
//

import SwiftUI

@main
struct DataFetchDemoApp: App {
  let dataFetcher: DataFetcher

  init() {
    self.dataFetcher = DataFetcher()

    Task(priority: .userInitiated) { [self] in
      await self.dataFetcher.prefetch(.initial)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView(dataFetcher: dataFetcher)
    }
  }
}
