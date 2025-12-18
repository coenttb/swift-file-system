//
//  File.System.Async Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Foundation
import Testing

@testable import File_System_Async

extension File.System.Async.Test.Unit {
    @Suite("File.System.Async")
    struct System {

        // MARK: - Test Fixtures

        private func createTempFile(content: [UInt8] = []) throws -> File.Path {
            let path = "/tmp/async-system-test-\(UUID().uuidString).txt"
            let data = Data(content)
            try data.write(to: URL(fileURLWithPath: path))
            return try File.Path(path)
        }

        private func createTempDir() throws -> File.Path {
            let path = "/tmp/async-system-test-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            return try File.Path(path)
        }

        private func cleanup(_ path: File.Path) {
            try? FileManager.default.removeItem(atPath: path.string)
        }

        // MARK: - Existence

        @Test("Check if file exists")
        func fileExists() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let path = try createTempFile(content: [1, 2, 3])
            defer { cleanup(path) }

            let exists = try await system.exists(path)
            #expect(exists)
        }

        @Test("Check if non-existent file does not exist")
        func fileDoesNotExist() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let path = try File.Path("/tmp/non-existent-\(UUID().uuidString).txt")
            let exists = try await system.exists(path)
            #expect(!exists)
        }

        // MARK: - Stat

        @Test("Get file metadata")
        func getFileMetadata() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let content: [UInt8] = [1, 2, 3, 4, 5]
            let path = try createTempFile(content: content)
            defer { cleanup(path) }

            let info = try await system.stat(path)
            #expect(info.size == UInt64(content.count))
            #expect(info.type == .regular)
        }

        // MARK: - Read/Write

        @Test("Read file contents")
        func readFileContents() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let content: [UInt8] = [10, 20, 30, 40, 50]
            let path = try createTempFile(content: content)
            defer { cleanup(path) }

            let read = try await system.readFull(path)
            #expect(read == content)
        }

        @Test("Write file atomically")
        func writeFileAtomically() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let path = try File.Path("/tmp/async-write-test-\(UUID().uuidString).txt")
            defer { cleanup(path) }

            let content: [UInt8] = [100, 101, 102, 103]
            try await system.writeAtomic(to: path, data: content)

            let read = try await system.readFull(path)
            #expect(read == content)
        }

        // MARK: - Copy/Move/Delete

        @Test("Copy file")
        func copyFile() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let content: [UInt8] = [1, 2, 3]
            let source = try createTempFile(content: content)
            let destination = try File.Path("/tmp/async-copy-dest-\(UUID().uuidString).txt")
            defer {
                cleanup(source)
                cleanup(destination)
            }

            try await system.copy(from: source, to: destination)

            let sourceExists = try await system.exists(source)
            let destExists = try await system.exists(destination)
            let destContent = try await system.readFull(destination)

            #expect(sourceExists)
            #expect(destExists)
            #expect(destContent == content)
        }

        @Test("Move file")
        func moveFile() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let content: [UInt8] = [1, 2, 3]
            let source = try createTempFile(content: content)
            let destination = try File.Path("/tmp/async-move-dest-\(UUID().uuidString).txt")
            defer {
                cleanup(source)
                cleanup(destination)
            }

            try await system.move(from: source, to: destination)

            let sourceExists = try await system.exists(source)
            let destExists = try await system.exists(destination)
            let destContent = try await system.readFull(destination)

            #expect(!sourceExists)
            #expect(destExists)
            #expect(destContent == content)
        }

        @Test("Delete file")
        func deleteFile() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let path = try createTempFile(content: [1, 2, 3])

            let existsBefore = try await system.exists(path)
            #expect(existsBefore)

            try await system.delete(path)

            let existsAfter = try await system.exists(path)
            #expect(!existsAfter)
        }

        // MARK: - Directory Operations

        @Test("Create directory")
        func createDirectory() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let path = try File.Path("/tmp/async-mkdir-test-\(UUID().uuidString)")
            defer { cleanup(path) }

            try await system.createDirectory(at: path)

            let exists = try await system.exists(path)
            let info = try await system.stat(path)
            #expect(exists)
            #expect(info.type == .directory)
        }

        @Test("List directory contents")
        func listDirectoryContents() async throws {
            let system = File.System.Async()
            defer { Task { await system.io.shutdown() } }

            let dir = try createTempDir()
            defer { cleanup(dir) }

            // Create some files
            try await system.writeAtomic(to: dir.appending("file1.txt"), data: [1])
            try await system.writeAtomic(to: dir.appending("file2.txt"), data: [2])

            let entries = try await system.directoryContents(at: dir)
            let names = Set(entries.map(\.name))

            #expect(names.contains("file1.txt"))
            #expect(names.contains("file2.txt"))
        }
    }
}
