//
//  File.System.Link.Hard.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Link {
    /// Hard link operations.
    public enum Hard {
        // TODO: Implementation
    }
}

extension File.System.Link.Hard {
    /// Error type for hard link operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case sourceNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case crossDevice(source: File.Path, destination: File.Path)
        case isDirectory(File.Path)
        case linkFailed(errno: Int32, message: String)
    }
}
