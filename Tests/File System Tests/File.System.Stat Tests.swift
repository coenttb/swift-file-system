//
//  File.System.Stat Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing
@testable import File_System
import Foundation

extension Test.`File System`.Unit {
    @Suite("File.System.Stat")
    struct Stat {

        // MARK: - Test Fixtures

        private func createTempFile(content: String = "test") throws -> String {
            let path = "/tmp/stat-test-\(UUID().uuidString).txt"
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return path
        }

        private func createTempDirectory() throws -> String {
            let path = "/tmp/stat-test-dir-\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            return path
        }

        private func cleanup(_ path: String) {
            try? FileManager.default.removeItem(atPath: path)
        }

        // MARK: - exists()

        @Test("exists returns true for existing file")
        func existsReturnsTrueForFile() throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.exists(at: filePath) == true)
        }

        @Test("exists returns true for existing directory")
        func existsReturnsTrueForDirectory() throws {
            let path = try createTempDirectory()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.exists(at: filePath) == true)
        }

        @Test("exists returns false for non-existing path")
        func existsReturnsFalseForNonExisting() throws {
            let filePath = try File.Path("/tmp/non-existing-\(UUID().uuidString)")
            #expect(File.System.Stat.exists(at: filePath) == false)
        }

        // MARK: - isFile()

        @Test("isFile returns true for regular file")
        func isFileReturnsTrueForFile() throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.isFile(at: filePath) == true)
        }

        @Test("isFile returns false for directory")
        func isFileReturnsFalseForDirectory() throws {
            let path = try createTempDirectory()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.isFile(at: filePath) == false)
        }

        @Test("isFile returns false for non-existing path")
        func isFileReturnsFalseForNonExisting() throws {
            let filePath = try File.Path("/tmp/non-existing-\(UUID().uuidString)")
            #expect(File.System.Stat.isFile(at: filePath) == false)
        }

        // MARK: - isDirectory()

        @Test("isDirectory returns true for directory")
        func isDirectoryReturnsTrueForDirectory() throws {
            let path = try createTempDirectory()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.isDirectory(at: filePath) == true)
        }

        @Test("isDirectory returns false for regular file")
        func isDirectoryReturnsFalseForFile() throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.isDirectory(at: filePath) == false)
        }

        @Test("isDirectory returns false for non-existing path")
        func isDirectoryReturnsFalseForNonExisting() throws {
            let filePath = try File.Path("/tmp/non-existing-\(UUID().uuidString)")
            #expect(File.System.Stat.isDirectory(at: filePath) == false)
        }

        // MARK: - isSymlink()

        @Test("isSymlink returns true for symlink")
        func isSymlinkReturnsTrueForSymlink() throws {
            let targetPath = try createTempFile()
            let linkPath = "/tmp/stat-test-link-\(UUID().uuidString)"
            defer {
                cleanup(targetPath)
                cleanup(linkPath)
            }

            try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: targetPath)

            let filePath = try File.Path(linkPath)
            #expect(File.System.Stat.isSymlink(at: filePath) == true)
        }

        @Test("isSymlink returns false for regular file")
        func isSymlinkReturnsFalseForFile() throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.isSymlink(at: filePath) == false)
        }

        @Test("isSymlink returns false for directory")
        func isSymlinkReturnsFalseForDirectory() throws {
            let path = try createTempDirectory()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(File.System.Stat.isSymlink(at: filePath) == false)
        }

        // MARK: - info()

        @Test("info returns correct type for file")
        func infoReturnsCorrectTypeForFile() throws {
            let path = try createTempFile(content: "Hello, World!")
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let info = try File.System.Stat.info(at: filePath)

            #expect(info.type == .regular)
            #expect(info.size == 13) // "Hello, World!" is 13 bytes
        }

        @Test("info returns correct type for directory")
        func infoReturnsCorrectTypeForDirectory() throws {
            let path = try createTempDirectory()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let info = try File.System.Stat.info(at: filePath)

            #expect(info.type == .directory)
        }

        @Test("info returns correct type for symlink")
        func infoReturnsCorrectTypeForSymlink() throws {
            let targetPath = try createTempFile()
            let linkPath = "/tmp/stat-test-link-\(UUID().uuidString)"
            defer {
                cleanup(targetPath)
                cleanup(linkPath)
            }

            try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: targetPath)

            let filePath = try File.Path(linkPath)
            let info = try File.System.Stat.info(at: filePath)

            // info() follows symlinks by default, so it should return the target type
            #expect(info.type == .regular)
        }

        @Test("info throws for non-existing path")
        func infoThrowsForNonExisting() throws {
            let filePath = try File.Path("/tmp/non-existing-\(UUID().uuidString)")

            #expect(throws: File.System.Stat.Error.self) {
                try File.System.Stat.info(at: filePath)
            }
        }

        // MARK: - Async variants

        @Test("async exists works")
        func asyncExists() async throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let exists = await File.System.Stat.exists(at: filePath)
            #expect(exists == true)
        }

        @Test("async isFile works")
        func asyncIsFile() async throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let isFile = await File.System.Stat.isFile(at: filePath)
            #expect(isFile == true)
        }

        @Test("async isDirectory works")
        func asyncIsDirectory() async throws {
            let path = try createTempDirectory()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let isDirectory = await File.System.Stat.isDirectory(at: filePath)
            #expect(isDirectory == true)
        }

        @Test("async info works")
        func asyncInfo() async throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let info = try await File.System.Stat.info(at: filePath)
            #expect(info.type == .regular)
        }

        // MARK: - Error cases

        @Test("pathNotFound error description")
        func pathNotFoundErrorDescription() throws {
            let path = try File.Path("/tmp/non-existing")
            let error = File.System.Stat.Error.pathNotFound(path)
            #expect(error.description.contains("Path not found"))
        }

        @Test("permissionDenied error description")
        func permissionDeniedErrorDescription() throws {
            let path = try File.Path("/root/restricted")
            let error = File.System.Stat.Error.permissionDenied(path)
            #expect(error.description.contains("Permission denied"))
        }

        @Test("statFailed error description")
        func statFailedErrorDescription() {
            let error = File.System.Stat.Error.statFailed(errno: 22, message: "Invalid argument")
            #expect(error.description.contains("Stat failed"))
            #expect(error.description.contains("Invalid argument"))
        }
    }
}
