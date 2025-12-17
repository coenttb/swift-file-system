//
//  File.Handle.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File {
    /// A managed file handle for reading and writing.
    ///
    /// `File.Handle` is a non-copyable type that owns a file descriptor
    /// along with metadata about how the file was opened.
    public struct Handle: ~Copyable, Sendable {
        // TODO: Implementation
    }
}
