//
//  File.System.Copy Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing
@testable import File_System_Primitives
import Foundation

extension File.System.Test.Unit {
    @Suite("File.System.Copy")
    struct Copy {

        // MARK: - Test Fixtures

        private func createTempFile(content: [UInt8] = [1, 2, 3]) throws -> String {
            let path = "/tmp/copy-test-\(UUID().uuidString).bin"
            let data = Data(content)
            try data.write(to: URL(fileURLWithPath: path))
            return path
        }

        private func cleanup(_ path: String) {
            try? FileManager.default.removeItem(atPath: path)
        }

        // MARK: - Basic Copy

        @Test("Copy file to new location")
        func copyFileToNewLocation() throws {
            let sourcePath = try createTempFile(content: [10, 20, 30, 40])
            let destPath = "/tmp/copy-dest-\(UUID().uuidString).bin"
            defer {
                cleanup(sourcePath)
                cleanup(destPath)
            }

            let source = try File.Path(sourcePath)
            let dest = try File.Path(destPath)

            try File.System.Copy.copy(from: source, to: dest)

            #expect(FileManager.default.fileExists(atPath: destPath))

            let sourceData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
            let destData = try Data(contentsOf: URL(fileURLWithPath: destPath))
            #expect(sourceData == destData)
        }

        @Test("Copy preserves source file")
        func copyPreservesSourceFile() throws {
            let sourcePath = try createTempFile(content: [1, 2, 3])
            let destPath = "/tmp/copy-dest-\(UUID().uuidString).bin"
            defer {
                cleanup(sourcePath)
                cleanup(destPath)
            }

            let source = try File.Path(sourcePath)
            let dest = try File.Path(destPath)

            try File.System.Copy.copy(from: source, to: dest)

            // Source should still exist
            #expect(FileManager.default.fileExists(atPath: sourcePath))
        }

        @Test("Copy empty file")
        func copyEmptyFile() throws {
            let sourcePath = try createTempFile(content: [])
            let destPath = "/tmp/copy-dest-\(UUID().uuidString).bin"
            defer {
                cleanup(sourcePath)
                cleanup(destPath)
            }

            let source = try File.Path(sourcePath)
            let dest = try File.Path(destPath)

            try File.System.Copy.copy(from: source, to: dest)

            let destData = try Data(contentsOf: URL(fileURLWithPath: destPath))
            #expect(destData.isEmpty)
        }

        // MARK: - Options

        @Test("Copy with overwrite option")
        func copyWithOverwriteOption() throws {
            let sourcePath = try createTempFile(content: [1, 2, 3])
            let destPath = try createTempFile(content: [99, 99])
            defer {
                cleanup(sourcePath)
                cleanup(destPath)
            }

            let source = try File.Path(sourcePath)
            let dest = try File.Path(destPath)

            let options = File.System.Copy.Options(overwrite: true)
            try File.System.Copy.copy(from: source, to: dest, options: options)

            let destData = try [UInt8](Data(contentsOf: URL(fileURLWithPath: destPath)))
            #expect(destData == [1, 2, 3])
        }

        @Test("Copy without overwrite throws when destination exists")
        func copyWithoutOverwriteThrows() throws {
            let sourcePath = try createTempFile(content: [1, 2, 3])
            let destPath = try createTempFile(content: [99, 99])
            defer {
                cleanup(sourcePath)
                cleanup(destPath)
            }

            let source = try File.Path(sourcePath)
            let dest = try File.Path(destPath)

            let options = File.System.Copy.Options(overwrite: false)
            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.copy(from: source, to: dest, options: options)
            }
        }

        @Test("Options default values")
        func optionsDefaultValues() {
            let options = File.System.Copy.Options()
            #expect(options.overwrite == false)
            #expect(options.copyAttributes == true)
            #expect(options.followSymlinks == true)
        }

        @Test("Options custom values")
        func optionsCustomValues() {
            let options = File.System.Copy.Options(
                overwrite: true,
                copyAttributes: false,
                followSymlinks: false
            )
            #expect(options.overwrite == true)
            #expect(options.copyAttributes == false)
            #expect(options.followSymlinks == false)
        }

        // MARK: - Error Cases

        @Test("Copy non-existent source throws sourceNotFound")
        func copyNonExistentSourceThrows() throws {
            let sourcePath = "/tmp/non-existent-\(UUID().uuidString).bin"
            let destPath = "/tmp/copy-dest-\(UUID().uuidString).bin"
            defer { cleanup(destPath) }

            let source = try File.Path(sourcePath)
            let dest = try File.Path(destPath)

            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.copy(from: source, to: dest)
            }
        }

        @Test("Copy to existing file without overwrite throws destinationExists")
        func copyToExistingFileThrows() throws {
            let sourcePath = try createTempFile(content: [1, 2, 3])
            let destPath = try createTempFile(content: [99])
            defer {
                cleanup(sourcePath)
                cleanup(destPath)
            }

            let source = try File.Path(sourcePath)
            let dest = try File.Path(destPath)

            #expect(throws: File.System.Copy.Error.destinationExists(dest)) {
                try File.System.Copy.copy(from: source, to: dest)
            }
        }

        // MARK: - Error Descriptions

        @Test("sourceNotFound error description")
        func sourceNotFoundErrorDescription() throws {
            let path = try File.Path.init("/tmp/missing")
            let error = File.System.Copy.Error.sourceNotFound(path)
            #expect(error.description.contains("Source not found"))
        }

        @Test("destinationExists error description")
        func destinationExistsErrorDescription() throws {
            let path = try File.Path.init("/tmp/existing")
            let error = File.System.Copy.Error.destinationExists(path)
            #expect(error.description.contains("already exists"))
        }

        @Test("permissionDenied error description")
        func permissionDeniedErrorDescription() throws {
            let path = try File.Path.init("/root/secret")
            let error = File.System.Copy.Error.permissionDenied(path)
            #expect(error.description.contains("Permission denied"))
        }

        @Test("isDirectory error description")
        func isDirectoryErrorDescription() throws {
            let path = try File.Path.init("/tmp")
            let error = File.System.Copy.Error.isDirectory(path)
            #expect(error.description.contains("Is a directory"))
        }

        @Test("copyFailed error description")
        func copyFailedErrorDescription() {
            let error = File.System.Copy.Error.copyFailed(errno: 5, message: "I/O error")
            #expect(error.description.contains("Copy failed"))
            #expect(error.description.contains("I/O error"))
        }

        // MARK: - Error Equatable

        @Test("Errors are equatable")
        func errorsAreEquatable() throws {
            let path1 = try File.Path.init("/tmp/a")
            let path2 = try File.Path.init("/tmp/a")

            #expect(File.System.Copy.Error.sourceNotFound(path1) == File.System.Copy.Error.sourceNotFound(path2))
            #expect(File.System.Copy.Error.destinationExists(path1) == File.System.Copy.Error.destinationExists(path2))
        }
    }
}
