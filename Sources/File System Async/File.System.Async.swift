//
//  File.System.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.System {
    /// The async file system façade.
    ///
    /// Holds `io` (executor) and provides async wrappers for primitive operations.
    /// All blocking I/O goes through `io.run`.
    ///
    /// ## Example
    /// ```swift
    /// let system = File.System.Async()
    /// let exists = try await system.exists(path)
    /// let info = try await system.stat(path)
    /// ```
    public struct Async: Sendable {
        /// The I/O executor for blocking operations.
        public let io: File.IO.Executor

        /// Creates a system façade with the given executor.
        ///
        /// - Parameter io: The I/O executor (default: new executor with default config).
        public init(io: File.IO.Executor = .init()) {
            self.io = io
        }

        // MARK: - Stat Operations

        /// Checks if a path exists.
        ///
        /// - Parameter path: The path to check.
        /// - Returns: `true` if the path exists.
        public func exists(_ path: File.Path) async throws -> Bool {
            try await io.run { File.System.Stat.exists(at: path) }
        }

        /// Gets metadata for a path.
        ///
        /// - Parameter path: The path to stat.
        /// - Returns: The metadata info.
        /// - Throws: `File.System.Stat.Error` on failure.
        public func stat(_ path: File.Path) async throws -> File.System.Metadata.Info {
            try await io.run { try File.System.Stat.info(at: path) }
        }

        // MARK: - Delete Operations

        /// Deletes a file or directory.
        ///
        /// - Parameters:
        ///   - path: The path to delete.
        ///   - options: Delete options.
        /// - Throws: `File.System.Delete.Error` on failure.
        public func delete(_ path: File.Path, options: File.System.Delete.Options = .init()) async throws {
            try await io.run { try File.System.Delete.delete(at: path, options: options) }
        }

        // MARK: - Copy Operations

        /// Copies a file.
        ///
        /// - Parameters:
        ///   - source: The source path.
        ///   - destination: The destination path.
        ///   - options: Copy options.
        /// - Throws: `File.System.Copy.Error` on failure.
        public func copy(
            from source: File.Path,
            to destination: File.Path,
            options: File.System.Copy.Options = .init()
        ) async throws {
            try await io.run { try File.System.Copy.copy(from: source, to: destination, options: options) }
        }

        // MARK: - Move Operations

        /// Moves or renames a file.
        ///
        /// - Parameters:
        ///   - source: The source path.
        ///   - destination: The destination path.
        ///   - options: Move options.
        /// - Throws: `File.System.Move.Error` on failure.
        public func move(
            from source: File.Path,
            to destination: File.Path,
            options: File.System.Move.Options = .init()
        ) async throws {
            try await io.run { try File.System.Move.move(from: source, to: destination, options: options) }
        }

        // MARK: - Directory Operations

        /// Creates a directory.
        ///
        /// - Parameters:
        ///   - path: The path for the directory.
        ///   - options: Create options.
        /// - Throws: `File.System.Create.Directory.Error` on failure.
        public func createDirectory(
            at path: File.Path,
            options: File.System.Create.Directory.Options = .init()
        ) async throws {
            try await io.run { try File.System.Create.Directory.create(at: path, options: options) }
        }

        /// Lists directory contents.
        ///
        /// - Parameter path: The directory path.
        /// - Returns: Array of directory entries.
        /// - Throws: `File.Directory.Contents.Error` on failure.
        public func directoryContents(at path: File.Path) async throws -> [File.Directory.Entry] {
            try await io.run { try File.Directory.Contents.list(at: path) }
        }

        // MARK: - Read Operations

        /// Reads the entire contents of a file.
        ///
        /// - Parameter path: The path to the file.
        /// - Returns: The file contents as bytes.
        /// - Throws: `File.System.Read.Error` on failure.
        public func readFull(_ path: File.Path) async throws -> [UInt8] {
            try await io.run { try File.System.Read.Full.read(from: path) }
        }

        // MARK: - Write Operations

        /// Writes data to a file atomically.
        ///
        /// - Parameters:
        ///   - path: The destination path.
        ///   - data: The data to write.
        ///   - options: Write options.
        /// - Throws: `File.System.Write.Atomic.Error` on failure.
        public func writeAtomic(
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

        /// Appends data to a file.
        ///
        /// - Parameters:
        ///   - path: The file path.
        ///   - data: The data to append.
        /// - Throws: `File.System.Write.Append.Error` on failure.
        public func append(
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
        ///   - link: The path for the symbolic link.
        ///   - target: The target path.
        /// - Throws: `File.System.Link.Symbolic.Error` on failure.
        public func createSymlink(at link: File.Path, pointingTo target: File.Path) async throws {
            try await io.run { try File.System.Link.Symbolic.create(at: link, pointingTo: target) }
        }

        /// Creates a hard link.
        ///
        /// - Parameters:
        ///   - link: The path for the hard link.
        ///   - target: The target path.
        /// - Throws: `File.System.Link.Hard.Error` on failure.
        public func createHardLink(at link: File.Path, to target: File.Path) async throws {
            try await io.run { try File.System.Link.Hard.create(at: link, to: target) }
        }

        /// Reads the target of a symbolic link.
        ///
        /// - Parameter path: The path to the symbolic link.
        /// - Returns: The target path.
        /// - Throws: `File.System.Link.ReadTarget.Error` on failure.
        public func readLinkTarget(_ path: File.Path) async throws -> File.Path {
            try await io.run { try File.System.Link.ReadTarget.target(of: path) }
        }
    }
}
