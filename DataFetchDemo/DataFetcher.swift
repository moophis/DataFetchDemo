//
//  DataFetcher.swift
//  DataFetchDemo
//
//

import Dispatch
import Foundation

struct Data: Identifiable {
  var id: String {
    self.payload
  }

  enum DataType {
    case network, cache
  }

  let payload: String
  let type: DataType

  init(payload: String, type: DataType) {
    self.payload = payload
    self.type = type
  }
}

public actor DataFetcher {
  enum FetchIntent {
    case initial, pagination
  }

  private var prefetchedStream: AsyncStream<Data>?

  func prefetch(_ intent: FetchIntent) {
    prefetchedStream = makeFetchStream(intent)
  }

  func makeFetchStream(_ intent: FetchIntent) -> AsyncStream<Data> {
    switch intent {
    case .initial:
      return makeInitialFetchStream()
    case .pagination:
      return makePaginationFetchStream()
    }
  }

  func fulfillPrefetchedStream() -> AsyncStream<Data>? {
    defer {
      prefetchedStream = nil
    }
    return prefetchedStream
  }

  private func makeInitialFetchStream() -> AsyncStream<Data> {
    AsyncStream { continuation in
      let cacheTask = Task {
        await withTaskCancellationHandler {
          Logger.d("DataFetcher: cache fetch deferral begin")
          // 4_000_000_000 -> cancelled or 1_000_000_000 -> not cancelled
          try? await Task.sleep(nanoseconds: 1_000_000_000)

          if Task.isCancelled {
            return
          }

          Logger.d("DataFetcher: cache fetch started")
          DataFetcher.fetchCache { data in
            if !Task.isCancelled {
              continuation.yield(data)

              Task(priority: .utility) {
                Logger.d("DataFetcher: run some side effects after cached data is fetched.")
              }
            }
          }
        } onCancel: {
          Logger.d("DataFetcher: cache fetch cancelded")
        }
      }

      Task {
        Logger.d("DataFetcher: initial network request started")
        DataFetcher.streamNetwork { data, index, isLastChunk in
          Logger.d("DataFetcher: initial network streaming - chunk: \(index), last chunk: \(isLastChunk)")
          if index == 0 {
            cacheTask.cancel()
          }
          continuation.yield(data)
          if isLastChunk {
            continuation.finish()
          }
        }
      }
    }
  }

  private func makePaginationFetchStream() -> AsyncStream<Data> {
    AsyncStream { continuation in
      Task {
        DataFetcher.streamNetwork { data, index, isLastChunk in
          Logger.d("DataFetcher: pagination network streaming - chunk: \(index), last chunk: \(isLastChunk)")
          continuation.yield(data)
          if isLastChunk {
            continuation.finish()
          }
        }
      }
    }
  }
}

/// Demo network / cache fetcher
extension DataFetcher {
  static func streamNetwork(_ completion: @escaping (Data, Int, Bool) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
      completion(Data(payload: "Network - 0 - false - \(Date.now)", type: .network), 0, false)
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
      completion(Data(payload: "Network - 1 - true - \(Date.now)", type: .network), 1, true)
    }
  }

  static func fetchCache(_ completion: @escaping (Data) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now()) {
      completion(Data(payload: "Cache - \(Date.now)", type: .cache))
    }
  }
}

public class Logger {
  static let printThreadInfo = true
  
  static func d(_ str: String) {
    if printThreadInfo {
      print("\(str) in \(String(describing: Thread.current)) (\(String(cString: __dispatch_queue_get_label(nil)))")
    } else {
      print("[\(Date.now)] \(str)")
    }
  }
}
