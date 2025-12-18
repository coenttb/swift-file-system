//
//  File.System.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.System {
    /// Internal async façade - prefer static async methods instead.
    ///
    /// Use the direct async overloads:
    /// ```swift
    /// let data = try await File.System.Read.Full.read(from: path)
    /// try await File.System.Copy.copy(from: a, to: b)
    /// ```
    public struct Async: Sendable {
        /// The I/O executor for blocking operations.
        let io: File.IO.Executor

        /// Creates a system façade with the given executor.
        init(io: File.IO.Executor = .default) {
            self.io = io
        }

        // MARK: - Stat Operations

        /// Checks if a path exists on the file system.
        ///
        /// - Parameter path: The path to check.
        /// - Returns: `true` if the path exists, `false` otherwise.
        func exists(_ path: File.Path) async throws -> Bool {
            try await io.run { File.System.Stat.exists(at: path) }
        }

        /// Returns metadata for a file or directory.
        ///
        /// - Parameter path: The path to stat.
        /// - Returns: Metadata including size, type, permissions, and timestamps.
        /// - Throws: `File.System.Stat.Error.notFound` if path doesn't exist.
        func stat(_ path: File.Path) async throws -> File.System.Metadata.Info {
            try await io.run { try File.System.Stat.info(at: path) }
        }

        // MARK: - Delete Operations

        /// Deletes a file or directory.
        ///
        /// - Parameters:
        ///   - path: The path to delete.
        ///   - options: Delete options (e.g., recursive for directories).
        /// - Throws: `File.System.Delete.Error` on failure.
        func delete(
            _ path: File.Path,
            options: File.System.Delete.Options = .init()
        ) async throws {
            try await io.run { try File.System.Delete.delete(at: path, options: options) }
        }

        // MARK: - Copy Operations

        /// Copies a file to a new location.
        ///
        /// - Parameters:
        ///   - source: The file to copy.
        ///   - destination: Where to copy it.
        ///   - options: Copy options (overwrite, preserve attributes).
        /// - Throws: `File.System.Copy.Error` on failure.
        func copy(
            from source: File.Path,
            to destination: File.Path,
            options: File.System.Copy.Options = .init()
        ) async throws {
            try await io.run {
                try File.System.Copy.copy(from: source, to: destination, options: options)
            }
        }

        // MARK: - Move Operations

        /// Moves or renames a file.
        ///
        /// Uses atomic rename when possible (same filesystem).
        ///
        /// - Parameters:
        ///   - source: The file to move.
        ///   - destination: The new location.
        ///   - options: Move options (overwrite behavior).
        /// - Throws: `File.System.Move.Error` on failure.
        func move(
            from source: File.Path,
            to destination: File.Path,
            options: File.System.Move.Options = .init()
        ) async throws {
            try await io.run {
                try File.System.Move.move(from: source, to: destination, options: options)
            }
        }

        // MARK: - Directory Operations

        /// Creates a directory at the specified path.
        ///
        /// - Parameters:
        ///   - path: Where to create the directory.
        ///   - options: Creation options (e.g., create intermediate directories).
        /// - Throws: `File.System.Create.Directory.Error` on failure.
        func createDirectory(
            at path: File.Path,
            options: File.System.Create.Directory.Options = .init()
        ) async throws {
            try await io.run { try File.System.Create.Directory.create(at: path, options: options) }
        }

        /// Lists entries in a directory.
        ///
        /// - Parameter path: The directory to list.
        /// - Returns: Array of directory entries (files, subdirectories, symlinks).
        /// - Throws: `File.Directory.Contents.Error` if not a directory or inaccessible.
        func directoryContents(at path: File.Path) async throws -> [File.Directory.Entry] {
            try await io.run { try File.Directory.Contents.list(at: path) }
        }

        // MARK: - Read Operations

        /// Reads the entire file into memory.
        ///
        /// - Parameter path: The file to read.
        /// - Returns: File contents as a byte array.
        /// - Throws: `File.System.Read.Full.Error` if file doesn't exist or can't be read.
        func readFull(_ path: File.Path) async throws -> [UInt8] {
            try await io.run { try File.System.Read.Full.read(from: path) }
        }

        // MARK: - Write Operations

        /// Atomically writes data to a file.
        ///
        /// Uses write-sync-rename pattern for crash safety. On success,
        /// the file contains the complete new data or the original state is preserved.
        ///
        /// - Parameters:
        ///   - path: Where to write the file.
        ///   - data: The bytes to write.
        ///   - options: Write options (strategy, durability, metadata preservation).
        /// - Throws: `File.System.Write.Atomic.Error` on failure.
        func writeAtomic(
            to path: File.Path,
            data: [UInt8],
            options: File.System.Write.Atomic.Options = .init()
        ) async throws {
            try await io.run {
                try data.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try File.System.Write.Atomic.write(span, to: path, options: options)
                }
            }
        }

        /// Appends data to an existing file.
        ///
        /// Creates the file if it doesn't exist.
        ///
        /// - Parameters:
        ///   - path: The file to append to.
        ///   - data: The bytes to append.
        /// - Throws: `File.System.Write.Append.Error` on failure.
        func append(
            to path: File.Path,
            data: [UInt8]
        ) async throws {
            try await io.run {
                try data.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try File.System.Write.Append.append(span, to: path)
                }
            }
        }

        // MARK: - Link Operations

        /// Creates a symbolic link.
        ///
        /// - Parameters:
        ///   - link: Path where the symlink will be created.
        ///   - target: The path the symlink points to (can be relative or absolute).
        /// - Throws: `File.System.Link.Symbolic.Error` on failure.
        func createSymlink(at link: File.Path, pointingTo target: File.Path) async throws {
            try await io.run { try File.System.Link.Symbolic.create(at: link, pointingTo: target) }
        }

        /// Creates a hard link.
        ///
        /// Both paths will reference the same file data on disk.
        ///
        /// - Parameters:
        ///   - link: Path where the hard link will be created.
        ///   - target: The existing file to link to (must be on same filesystem).
        /// - Throws: `File.System.Link.Hard.Error` on failure.
        func createHardLink(at link: File.Path, to target: File.Path) async throws {
            try await io.run { try File.System.Link.Hard.create(at: link, to: target) }
        }

        /// Reads the target of a symbolic link.
        ///
        /// - Parameter path: The symlink to read.
        /// - Returns: The path the symlink points to.
        /// - Throws: `File.System.Link.ReadTarget.Error` if not a symlink.
        func readLinkTarget(_ path: File.Path) async throws -> File.Path {
            try await io.run { try File.System.Link.ReadTarget.target(of: path) }
        }
    }
}
