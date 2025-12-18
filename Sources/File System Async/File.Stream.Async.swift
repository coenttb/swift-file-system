//
//  File.Stream.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File {
    /// Namespace for streaming file APIs.
    public enum Stream {}
}

extension File.Stream {
    /// Async streaming APIs.
    ///
    /// Provides byte streaming via `bytes(from:)`.
    public struct Async: Sendable {
        let io: File.IO.Executor

        /// Creates an async stream API with the given executor.
        public init(io: File.IO.Executor) {
            self.io = io
        }
    }
}
