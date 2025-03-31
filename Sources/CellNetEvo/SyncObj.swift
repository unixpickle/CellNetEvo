import Foundation

public class SyncObj<T: Sendable>: @unchecked Sendable {
  private var obj: T
  private let lock = NSLock()

  public init(_ obj: T) {
    self.obj = obj
  }

  public func use<R>(fn: (inout T) -> R) -> R {
    lock.withLock { fn(&obj) }
  }
}
