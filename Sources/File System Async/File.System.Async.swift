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

        func exists(_ path: File.Path) async throws -> Bool {
            try await io.run { File.System.Stat.exists(at: path) }
        }

        func stat(_ path: File.Path) async throws -> File.System.Metadata.Info {
            try await io.run { try File.System.Stat.info(at: path) }
        }

        // MARK: - Delete Operations

        func delete(
            _ path: File.Path,
            options: File.System.Delete.Options = .init()
        ) async throws {
            try await io.run { try File.System.Delete.delete(at: path, options: options) }
        }

        // MARK: - Copy Operations

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

        func createDirectory(
            at path: File.Path,
            options: File.System.Create.Directory.Options = .init()
        ) async throws {
            try await io.run { try File.System.Create.Directory.create(at: path, options: options) }
        }

        func directoryContents(at path: File.Path) async throws -> [File.Directory.Entry] {
            try await io.run { try File.Directory.Contents.list(at: path) }
        }

        // MARK: - Read Operations

        func readFull(_ path: File.Path) async throws -> [UInt8] {
            try await io.run { try File.System.Read.Full.read(from: path) }
        }

        // MARK: - Write Operations

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

        func createSymlink(at link: File.Path, pointingTo target: File.Path) async throws {
            try await io.run { try File.System.Link.Symbolic.create(at: link, pointingTo: target) }
        }

        func createHardLink(at link: File.Path, to target: File.Path) async throws {
            try await io.run { try File.System.Link.Hard.create(at: link, to: target) }
        }

        func readLinkTarget(_ path: File.Path) async throws -> File.Path {
            try await io.run { try File.System.Link.ReadTarget.target(of: path) }
        }
    }
}
