//
//  File.System.Read.Full.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Read {
    /// Read entire file contents into memory.
    public enum Full {
        // TODO: Implementation
    }
}

extension File.System.Read.Full {
    /// Error type for full file read operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case readFailed(errno: Int32, message: String)
        case tooManyOpenFiles
    }
}
