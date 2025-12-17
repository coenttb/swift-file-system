//
//  File.System.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Unified error type for file system operations.
    ///
    /// Note: Prefer using operation-specific error types (e.g., `File.System.Read.Full.Error`)
    /// for typed throws. This unified type is for cases where a common error type is needed.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case isDirectory(File.Path)
        case notADirectory(File.Path)
        case notEmpty(File.Path)
        case crossDevice(source: File.Path, destination: File.Path)
        case tooManyOpenFiles
        case diskFull
        case ioError(errno: Int32, message: String)
        case unknown(errno: Int32, message: String)
    }
}
