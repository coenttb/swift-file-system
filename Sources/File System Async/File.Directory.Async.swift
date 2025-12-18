//
//  File.Directory.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory {
    /// Async directory APIs.
    ///
    /// Provides streaming directory iteration via `entries(at:)`.
    public struct Async: Sendable {
        let io: File.IO.Executor

        /// Creates an async directory API with the given executor.
        public init(io: File.IO.Executor) {
            self.io = io
        }

        /// Lists directory contents (non-streaming).
        ///
        /// - Parameter path: The directory path.
        /// - Returns: Array of directory entries.
        /// - Throws: `File.Directory.Contents.Error` on failure.
        public func contents(at path: File.Path) async throws -> [File.Directory.Entry] {
            try await io.run { try File.Directory.Contents.list(at: path) }
        }
    }
}
