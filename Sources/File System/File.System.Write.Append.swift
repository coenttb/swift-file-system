//
//  File.System.Write.Append.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write {
    /// Append data to existing files.
    public enum Append {
        // TODO: Implementation
    }
}

extension File.System.Write.Append {
    /// Error type for append operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case writeFailed(errno: Int32, message: String)
    }
}
