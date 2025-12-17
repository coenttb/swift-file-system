//
//  File.System.Link.ReadTarget.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Link {
    /// Read symbolic link target.
    public enum ReadTarget {
        // TODO: Implementation
    }
}

extension File.System.Link.ReadTarget {
    /// Error type for reading link target operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case notASymlink(File.Path)
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case readFailed(errno: Int32, message: String)
    }
}
