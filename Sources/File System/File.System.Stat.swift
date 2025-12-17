//
//  File.System.Stat.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import WinSDK
#endif

extension File.System {
    /// File status and existence checks.
    public enum Stat {}
}

// MARK: - Error

extension File.System.Stat {
    /// Errors that can occur during stat operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case statFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Stat {
    /// Gets file metadata information.
    ///
    /// - Parameter path: The path to stat.
    /// - Returns: File metadata information.
    /// - Throws: `File.System.Stat.Error` on failure.
    public static func info(at path: File.Path) throws(Error) -> File.System.Metadata.Info {
        #if os(Windows)
        return try _infoWindows(at: path)
        #else
        return try _infoPOSIX(at: path)
        #endif
    }

    /// Checks if a path exists.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path exists, `false` otherwise.
    public static func exists(at path: File.Path) -> Bool {
        #if os(Windows)
        return _existsWindows(at: path)
        #else
        return _existsPOSIX(at: path)
        #endif
    }

    /// Checks if the path is a regular file.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a regular file, `false` otherwise.
    public static func isFile(at path: File.Path) -> Bool {
        guard let info = try? info(at: path) else { return false }
        return info.type == .regular
    }

    /// Checks if the path is a directory.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a directory, `false` otherwise.
    public static func isDirectory(at path: File.Path) -> Bool {
        guard let info = try? info(at: path) else { return false }
        return info.type == .directory
    }

    /// Checks if the path is a symbolic link.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a symbolic link, `false` otherwise.
    public static func isSymlink(at path: File.Path) -> Bool {
        #if os(Windows)
        return _isSymlinkWindows(at: path)
        #else
        return _isSymlinkPOSIX(at: path)
        #endif
    }
}

// MARK: - Async API

extension File.System.Stat {
    /// Gets file metadata information.
    ///
    /// Async variant.
    public static func info(at path: File.Path) async throws(Error) -> File.System.Metadata.Info {
        #if os(Windows)
        return try _infoWindows(at: path)
        #else
        return try _infoPOSIX(at: path)
        #endif
    }

    /// Checks if a path exists.
    ///
    /// Async variant.
    public static func exists(at path: File.Path) async -> Bool {
        #if os(Windows)
        return _existsWindows(at: path)
        #else
        return _existsPOSIX(at: path)
        #endif
    }

    /// Checks if the path is a regular file.
    ///
    /// Async variant.
    public static func isFile(at path: File.Path) async -> Bool {
        #if os(Windows)
        guard let info = try? _infoWindows(at: path) else { return false }
        #else
        guard let info = try? _infoPOSIX(at: path) else { return false }
        #endif
        return info.type == .regular
    }

    /// Checks if the path is a directory.
    ///
    /// Async variant.
    public static func isDirectory(at path: File.Path) async -> Bool {
        #if os(Windows)
        guard let info = try? _infoWindows(at: path) else { return false }
        #else
        guard let info = try? _infoPOSIX(at: path) else { return false }
        #endif
        return info.type == .directory
    }

    /// Checks if the path is a symbolic link.
    ///
    /// Async variant.
    public static func isSymlink(at path: File.Path) async -> Bool {
        #if os(Windows)
        return _isSymlinkWindows(at: path)
        #else
        return _isSymlinkPOSIX(at: path)
        #endif
    }
}

// MARK: - CustomStringConvertible for Error

extension File.System.Stat.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .statFailed(let errno, let message):
            return "Stat failed: \(message) (errno=\(errno))"
        }
    }
}
