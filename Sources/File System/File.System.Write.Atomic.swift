// File.System.Write.Atomic.swift
// Atomic file writing with crash-safety guarantees
//
// This module provides atomic file writes using the standard pattern:
//   1. Write to a temporary file in the same directory
//   2. Sync the file to disk (fsync)
//   3. Atomically rename temp → destination (rename is atomic on POSIX/NTFS)
//   4. Sync the directory to ensure the rename is persisted
//
// This guarantees that on any crash or power failure, you either have:
//   - The complete new file, or
//   - The complete old file (or no file if it didn't exist)
// You never get a partial/corrupted file.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import WinSDK
#endif

public import Binary
public import INCITS_4_1986

extension File.System.Write {
    public enum Atomic {

        // MARK: - Strategy

        /// Controls behavior when the destination file already exists.
        public enum Strategy: Sendable {
            /// Replace the existing file atomically (default).
            /// The old file is replaced in a single atomic operation.
            case replaceExisting

            /// Fail if the destination already exists.
            /// Note: On some platforms this has a small race window (TOCTOU).
            /// Linux with kernel 3.15+ uses `renameat2(RENAME_NOREPLACE)` for true atomicity.
            case noClobber
        }

        // MARK: - Options

        /// Options controlling atomic write behavior.
        public struct Options: Sendable {
            /// Strategy for handling existing files.
            public var strategy: Strategy

            /// If true and destination exists, copy its permissions (mode) to the new file.
            /// Default: true
            public var preservePermissions: Bool

            /// If true and destination exists, copy its owner/group to the new file.
            /// Note: Requires appropriate privileges; failures are ignored unless `strictOwnership` is true.
            /// Default: false (changing ownership usually requires root)
            public var preserveOwnership: Bool

            /// If true, fail when ownership cannot be preserved. If false, ownership errors are ignored.
            /// Only relevant when `preserveOwnership` is true.
            /// Default: false
            public var strictOwnership: Bool

            /// If true and destination exists, copy its timestamps (atime/mtime) to the new file.
            /// Default: false
            public var preserveTimestamps: Bool

            /// If true and destination exists, copy extended attributes (xattrs) to the new file.
            /// Supported on macOS and Linux. Silently skipped on unsupported platforms.
            /// Default: false
            public var preserveExtendedAttributes: Bool

            /// If true and destination exists, copy ACLs to the new file.
            /// Requires ACL shims to be compiled (ATOMICFILEWRITE_HAS_ACL_SHIMS).
            /// Default: false
            public var preserveACLs: Bool

            public init(
                strategy: Strategy = .replaceExisting,
                preservePermissions: Bool = true,
                preserveOwnership: Bool = false,
                strictOwnership: Bool = false,
                preserveTimestamps: Bool = false,
                preserveExtendedAttributes: Bool = false,
                preserveACLs: Bool = false
            ) {
                self.strategy = strategy
                self.preservePermissions = preservePermissions
                self.preserveOwnership = preserveOwnership
                self.strictOwnership = strictOwnership
                self.preserveTimestamps = preserveTimestamps
                self.preserveExtendedAttributes = preserveExtendedAttributes
                self.preserveACLs = preserveACLs
            }

            /// Preset: Only atomic replacement, no metadata preservation.
            public static var minimal: Options {
                Options(preservePermissions: false)
            }

            /// Preset: Preserve all metadata that can be preserved without special privileges.
            public static var preserveAll: Options {
                Options(
                    preservePermissions: true,
                    preserveOwnership: true,
                    strictOwnership: false,
                    preserveTimestamps: true,
                    preserveExtendedAttributes: true,
                    preserveACLs: false  // Requires shims, keep off by default
                )
            }
        }

        // MARK: - Errors

        public enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
            // Path validation errors
            case invalidPath(reason: String)

            // Parent directory errors
            case parentNotFound(path: String)
            case parentNotDirectory(path: String)
            case parentAccessDenied(path: String)

            // Destination inspection errors
            case destinationStatFailed(path: String, errno: Int32, message: String)

            // Temp file errors
            case tempFileCreationFailed(directory: String, errno: Int32, message: String)

            // Write errors
            case writeFailed(bytesWritten: Int, bytesExpected: Int, errno: Int32, message: String)

            // Sync errors
            case syncFailed(errno: Int32, message: String)
            case closeFailed(errno: Int32, message: String)

            // Metadata errors
            case metadataPreservationFailed(operation: String, errno: Int32, message: String)

            // Rename errors
            case renameFailed(from: String, to: String, errno: Int32, message: String)
            case destinationExists(path: String)

            // Directory sync errors
            case directorySyncFailed(path: String, errno: Int32, message: String)

            public var description: String {
                switch self {
                case .invalidPath(let reason):
                    return "Invalid path: \(reason)"
                case .parentNotFound(let path):
                    return "Parent directory not found: \(path)"
                case .parentNotDirectory(let path):
                    return "Parent path is not a directory: \(path)"
                case .parentAccessDenied(let path):
                    return "Access denied to parent directory: \(path)"
                case .destinationStatFailed(let path, let errno, let message):
                    return "Failed to stat destination '\(path)': \(message) (errno=\(errno))"
                case .tempFileCreationFailed(let directory, let errno, let message):
                    return "Failed to create temp file in '\(directory)': \(message) (errno=\(errno))"
                case .writeFailed(let written, let expected, let errno, let message):
                    return "Write failed after \(written)/\(expected) bytes: \(message) (errno=\(errno))"
                case .syncFailed(let errno, let message):
                    return "Sync failed: \(message) (errno=\(errno))"
                case .closeFailed(let errno, let message):
                    return "Close failed: \(message) (errno=\(errno))"
                case .metadataPreservationFailed(let op, let errno, let message):
                    return "Metadata preservation failed (\(op)): \(message) (errno=\(errno))"
                case .renameFailed(let from, let to, let errno, let message):
                    return "Rename failed '\(from)' → '\(to)': \(message) (errno=\(errno))"
                case .destinationExists(let path):
                    return "Destination already exists (noClobber): \(path)"
                case .directorySyncFailed(let path, let errno, let message):
                    return "Directory sync failed '\(path)': \(message) (errno=\(errno))"
                }
            }
        }

        // MARK: - Public API (File.Path)

        /// Atomically writes bytes to a file path using a zero-copy Span.
        ///
        /// This is the most efficient overload - it avoids copying the data.
        ///
        /// ## Guarantees
        /// - Either the file exists with complete contents, or the original state is preserved
        /// - On success, data is synced to physical storage (survives power loss)
        /// - Safe to call concurrently for different paths
        ///
        /// ## Requirements
        /// - Parent directory must exist and be writable
        ///
        /// - Parameters:
        ///   - bytes: The data to write (borrowed, not copied)
        ///   - path: Destination file path
        ///   - options: Write options (default: replace existing, preserve permissions)
        /// - Throws: `File.System.Write.Atomic.Error` on failure
        public static func write(
            _ bytes: borrowing Swift.Span<UInt8>,
            to path: File.Path,
            options: borrowing Options = Options()
        ) throws(Error) {
            // File.Path is guaranteed to be non-empty and free of control characters
            #if os(Windows)
            try WindowsAtomic.writeSpan(bytes, to: path.string, options: options)
            #else
            try POSIXAtomic.writeSpan(bytes, to: path.string, options: options)
            #endif
        }

        /// Atomically writes bytes to a file path.
        ///
        /// ## Guarantees
        /// - Either the file exists with complete contents, or the original state is preserved
        /// - On success, data is synced to physical storage (survives power loss)
        /// - Safe to call concurrently for different paths
        ///
        /// ## Requirements
        /// - Parent directory must exist and be writable
        ///
        /// - Parameters:
        ///   - bytes: The data to write
        ///   - path: Destination file path
        ///   - options: Write options (default: replace existing, preserve permissions)
        /// - Throws: `File.System.Write.Atomic.Error` on failure
        @inlinable
        public static func write(
            _ bytes: [UInt8],
            to path: File.Path,
            options: Options = Options()
        ) throws(Error) {
            try bytes.withUnsafeBufferPointer { buffer throws(Error) in
                let span = Swift.Span(_unsafeElements: buffer)
                try write(span, to: path, options: options)
            }
        }

        /// Atomically writes a contiguous collection of bytes to a file path.
        @inlinable
        public static func write<C: Collection>(
            contentsOf bytes: C,
            to path: File.Path,
            options: Options = Options()
        ) throws(Error) where C.Element == UInt8 {
            try write(Array(bytes), to: path, options: options)
        }

        /// Atomically writes an unsafe buffer pointer to a file path.
        ///
        /// This overload is useful when you already have an unsafe buffer pointer
        /// and want to avoid copying to an Array first.
        @inlinable
        public static func write(
            _ buffer: UnsafeBufferPointer<UInt8>,
            to path: File.Path,
            options: Options = Options()
        ) throws(Error) {
            let span = Swift.Span(_unsafeElements: buffer)
            try write(span, to: path, options: options)
        }

        /// Atomically writes raw bytes from an unsafe raw buffer pointer.
        @inlinable
        public static func write(
            _ buffer: UnsafeRawBufferPointer,
            to path: File.Path,
            options: Options = Options()
        ) throws(Error) {
            let span = Swift.Span<UInt8>(_unsafeBytes: buffer)
            try write(span, to: path, options: options)
        }

        // MARK: - Binary.Serializable (File.Path)

        /// Atomically writes a Binary.Serializable value to a file path.
        ///
        /// This overload accepts any type conforming to `Binary.Serializable`,
        /// serializing it to bytes before writing atomically.
        ///
        /// ## Example
        /// ```swift
        /// try File.System.Write.Atomic.write(document, to: File.Path("/path/to/file.pdf"))
        /// ```
        ///
        /// - Parameters:
        ///   - serializable: The value to serialize and write
        ///   - path: Destination file path
        ///   - options: Write options (default: replace existing, preserve permissions)
        /// - Throws: `File.System.Write.Atomic.Error` on failure
        @inlinable
        public static func write<S: Binary.Serializable>(
            _ serializable: S,
            to path: File.Path,
            options: Options = Options()
        ) throws(Error) {
            var buffer: [UInt8] = []
            S.serialize(serializable, into: &buffer)
            try write(buffer, to: path, options: options)
        }

        /// Atomically writes a Binary.Serializable value with a capacity hint.
        ///
        /// Use this overload when you know the approximate size of the serialized
        /// output to avoid intermediate buffer reallocations.
        ///
        /// - Parameters:
        ///   - serializable: The value to serialize and write
        ///   - path: Destination file path
        ///   - bufferCapacity: Hint for pre-allocating the serialization buffer
        ///   - options: Write options (default: replace existing, preserve permissions)
        /// - Throws: `File.System.Write.Atomic.Error` on failure
        @inlinable
        public static func write<S: Binary.Serializable>(
            _ serializable: S,
            to path: File.Path,
            bufferCapacity: Int,
            options: Options = Options()
        ) throws(Error) {
            var buffer: [UInt8] = []
            buffer.reserveCapacity(bufferCapacity)
            S.serialize(serializable, into: &buffer)
            try write(buffer, to: path, options: options)
        }

        // MARK: - Public API (String convenience)

        /// Atomically writes bytes to a file path using a zero-copy Span.
        ///
        /// This is a convenience overload that accepts a `String` path.
        /// Prefer using `File.Path` for type safety.
        @inlinable
        public static func write(
            _ bytes: borrowing Swift.Span<UInt8>,
            to path: String,
            options: borrowing Options = Options()
        ) throws(Error) {
            let filePath: File.Path
            do { filePath = try File.Path(path) }
            catch { throw .init(error) }
            try write(bytes, to: filePath, options: options)
        }

        /// Atomically writes bytes to a file path.
        ///
        /// This is a convenience overload that accepts a `String` path.
        /// Prefer using `File.Path` for type safety.
        @inlinable
        public static func write(
            _ bytes: [UInt8],
            to path: String,
            options: Options = Options()
        ) throws(Error) {
            let filePath: File.Path
            do { filePath = try File.Path(path) }
            catch { throw .init(error) }
            try write(bytes, to: filePath, options: options)
        }

        /// Atomically writes a contiguous collection of bytes to a file path.
        ///
        /// This is a convenience overload that accepts a `String` path.
        /// Prefer using `File.Path` for type safety.
        @inlinable
        public static func write<C: Collection>(
            contentsOf bytes: C,
            to path: String,
            options: Options = Options()
        ) throws(Error) where C.Element == UInt8 {
            let filePath: File.Path
            do { filePath = try File.Path(path) }
            catch { throw .init(error) }
            try write(contentsOf: bytes, to: filePath, options: options)
        }

        /// Atomically writes an unsafe buffer pointer to a file path.
        ///
        /// This is a convenience overload that accepts a `String` path.
        /// Prefer using `File.Path` for type safety.
        @inlinable
        public static func write(
            _ buffer: UnsafeBufferPointer<UInt8>,
            to path: String,
            options: Options = Options()
        ) throws(Error) {
            let filePath: File.Path
            do { filePath = try File.Path(path) }
            catch { throw .init(error) }
            try write(buffer, to: filePath, options: options)
        }

        /// Atomically writes raw bytes from an unsafe raw buffer pointer.
        ///
        /// This is a convenience overload that accepts a `String` path.
        /// Prefer using `File.Path` for type safety.
        @inlinable
        public static func write(
            _ buffer: UnsafeRawBufferPointer,
            to path: String,
            options: Options = Options()
        ) throws(Error) {
            let filePath: File.Path
            do { filePath = try File.Path(path) }
            catch { throw .init(error) }
            try write(buffer, to: filePath, options: options)
        }

        /// Atomically writes a Binary.Serializable value to a file path.
        ///
        /// This is a convenience overload that accepts a `String` path.
        /// Prefer using `File.Path` for type safety.
        @inlinable
        public static func write<S: Binary.Serializable>(
            _ serializable: S,
            to path: String,
            options: Options = Options()
        ) throws(Error) {
            let filePath: File.Path
            do { filePath = try File.Path(path) }
            catch { throw .init(error) }
            try write(serializable, to: filePath, options: options)
        }

        /// Atomically writes a Binary.Serializable value with a capacity hint.
        ///
        /// This is a convenience overload that accepts a `String` path.
        /// Prefer using `File.Path` for type safety.
        @inlinable
        public static func write<S: Binary.Serializable>(
            _ serializable: S,
            to path: String,
            bufferCapacity: Int,
            options: Options = Options()
        ) throws(Error) {
            let filePath: File.Path
            do { filePath = try File.Path(path) }
            catch { throw .init(error) }
            try write(serializable, to: filePath, bufferCapacity: bufferCapacity, options: options)
        }
    }
}

// MARK: - Internal Helpers

extension File.System.Write.Atomic.Error {
    /// Creates an error from a `File.Path.Error`.
    @usableFromInline
    init(_ pathError: File.Path.Error) {
        switch pathError {
        case .empty:
            self = .invalidPath(reason: "path is empty")
        case .containsControlCharacters:
            self = .invalidPath(reason: "path contains control characters")
        }
    }
}

extension File.System.Write.Atomic {
    /// Converts errno to a human-readable message.
    @usableFromInline
    static func errorMessage(for errno: Int32) -> String {
        #if os(Windows)
        return "error \(errno)"
        #else
        if let cString = strerror(errno) {
            return String(cString: cString)
        }
        return "error \(errno)"
        #endif
    }
}

// MARK: - Binary.Serializable Extension

extension Binary.Serializable {
    /// Atomically writes this value to a file path.
    ///
    /// This extension provides a fluent API for atomic file writing:
    /// ```swift
    /// try document.write(to: "/path/to/file.pdf")
    /// ```
    ///
    /// - Parameters:
    ///   - path: Destination file path
    ///   - options: Write options (default: replace existing, preserve permissions)
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    @inlinable
    public func write(
        to path: String,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try File.System.Write.Atomic.write(self, to: path, options: options)
    }
}

// MARK: - Binary.ASCII.Wrapper Extension

extension Binary.ASCII.Wrapper where Wrapped: Binary.ASCII.Serializable {
    /// Atomically writes the ASCII serialization of this value to a file.
    ///
    /// Uses ASCII serialization (not binary) for the wrapped value.
    ///
    /// ## Example
    /// ```swift
    /// // For types with both binary and ASCII serializations:
    /// try ipAddress.ascii.write(to: "/path/to/file.txt")
    /// ```
    ///
    /// - Parameters:
    ///   - path: Destination file path
    ///   - options: Write options (default: replace existing, preserve permissions)
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    @inlinable
    public func write(
        to path: String,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        var buffer: [UInt8] = []
        Wrapped.serialize(ascii: wrapped, into: &buffer)
        try File.System.Write.Atomic.write(buffer, to: path, options: options)
    }
}
