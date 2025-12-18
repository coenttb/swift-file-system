//
//  File.IO.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

public import Foundation

extension File {
    /// Namespace for I/O coordination.
    ///
    /// Contains the `Executor` for running blocking I/O operations
    /// on a bounded cooperative pool.
    public enum IO {}
}

extension File.IO {
    /// Configuration for the I/O executor.
    public struct Configuration: Sendable {
        /// Number of concurrent workers.
        public var workers: Int

        /// Maximum number of jobs in the queue.
        public var queueLimit: Int

        /// Default number of workers based on system resources.
        public static var defaultWorkerCount: Int {
            ProcessInfo.processInfo.activeProcessorCount
        }

        /// Creates a configuration.
        ///
        /// - Parameters:
        ///   - workers: Number of concurrent workers (default: active processor count).
        ///   - queueLimit: Maximum queue size (default: 10,000).
        public init(
            workers: Int? = nil,
            queueLimit: Int = 10_000
        ) {
            self.workers = max(1, workers ?? Self.defaultWorkerCount)
            self.queueLimit = max(1, queueLimit)
        }
    }
}
