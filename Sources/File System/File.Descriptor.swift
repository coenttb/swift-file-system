//
//  File.Descriptor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File {
    /// A low-level file descriptor wrapper.
    ///
    /// `File.Descriptor` is a non-copyable type that owns a file descriptor
    /// and ensures it is properly closed when the descriptor goes out of scope.
    public struct Descriptor: ~Copyable, Sendable {
        // TODO: Implementation
    }
}
