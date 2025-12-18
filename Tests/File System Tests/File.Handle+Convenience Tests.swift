//
//  File.Handle+Convenience Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing
@testable import File_System
import Foundation

extension Test.`File System`.Unit {
    @Suite("File.Handle+Convenience")
    struct HandleConvenience {

        // MARK: - Test Fixtures

        private func createTempFile(content: [UInt8] = []) throws -> String {
            let path = "/tmp/handle-convenience-test-\(UUID().uuidString).bin"
            let data = Data(content)
            try data.write(to: URL(fileURLWithPath: path))
            return path
        }

        private func cleanup(_ path: String) {
            try? FileManager.default.removeItem(atPath: path)
        }

        // MARK: - withOpen

        @Test("withOpen reads file content")
        func withOpenReadsContent() throws {
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let path = try createTempFile(content: content)
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let readData = try File.Handle.withOpen(filePath, mode: .read) { handle in
                try handle.read(count: 10)
            }

            #expect(readData == content)
        }

        @Test("withOpen writes file content")
        func withOpenWritesContent() throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let dataToWrite: [UInt8] = [10, 20, 30, 40, 50]

            try File.Handle.withOpen(filePath, mode: .write, options: [.truncate]) { handle in
                try dataToWrite.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try handle.write(span)
                }
            }

            let readBack = try [UInt8](Data(contentsOf: URL(fileURLWithPath: path)))
            #expect(readBack == dataToWrite)
        }

        @Test("withOpen closes handle after normal completion")
        func withOpenClosesHandleNormally() throws {
            let content: [UInt8] = [1, 2, 3]
            let path = try createTempFile(content: content)
            defer { cleanup(path) }

            let filePath = try File.Path(path)

            // After withOpen completes, the handle should be closed
            // We verify this by being able to open it again
            _ = try File.Handle.withOpen(filePath, mode: .read) { handle in
                try handle.read(count: 3)
            }

            // If handle wasn't closed, this might fail or behave unexpectedly
            let secondRead = try File.Handle.withOpen(filePath, mode: .read) { handle in
                try handle.read(count: 3)
            }

            #expect(secondRead == content)
        }

        @Test("withOpen closes handle after error")
        func withOpenClosesHandleAfterError() throws {
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)

            struct TestError: Error {}

            // The handle should be closed even if the closure throws
            do {
                try File.Handle.withOpen(filePath, mode: .read) { _ in
                    throw TestError()
                }
                Issue.record("Expected error to be thrown")
            } catch is TestError {
                // Expected
            }

            // Verify handle was closed by opening successfully again
            let result = try File.Handle.withOpen(filePath, mode: .read) { handle in
                try handle.read(count: 10)
            }
            #expect(result.isEmpty)
        }

        @Test("withOpen returns closure result")
        func withOpenReturnsResult() throws {
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let path = try createTempFile(content: content)
            defer { cleanup(path) }

            let filePath = try File.Path(path)

            let sum = try File.Handle.withOpen(filePath, mode: .read) { handle in
                let bytes = try handle.read(count: 10)
                return bytes.reduce(0, +)
            }

            #expect(sum == 55) // 1+2+3+4+5+6+7+8+9+10
        }

        @Test("withOpen with create option creates file")
        func withOpenCreatesFile() throws {
            let path = "/tmp/handle-convenience-create-\(UUID().uuidString).txt"
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            #expect(!FileManager.default.fileExists(atPath: path))

            try File.Handle.withOpen(filePath, mode: .write, options: [.create]) { handle in
                let bytes: [UInt8] = [72, 105] // "Hi"
                try bytes.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try handle.write(span)
                }
            }

            #expect(FileManager.default.fileExists(atPath: path))
        }

        @Test("withOpen propagates open error")
        func withOpenPropagatesOpenError() throws {
            let nonExistent = "/tmp/non-existent-\(UUID().uuidString).txt"
            let filePath = try File.Path(nonExistent)

            #expect(throws: File.Handle.Error.self) {
                try File.Handle.withOpen(filePath, mode: .read) { _ in
                    // Should never reach here
                }
            }
        }

        // MARK: - Async withOpen

        @Test("async withOpen reads file content")
        func asyncWithOpenReadsContent() async throws {
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let path = try createTempFile(content: content)
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let readData = try await File.Handle.withOpen(filePath, mode: .read) { handle in
                try handle.read(count: 10)
            }

            #expect(readData == content)
        }

        @Test("async withOpen with async body")
        func asyncWithOpenAsyncBody() async throws {
            let content: [UInt8] = [1, 2, 3]
            let path = try createTempFile(content: content)
            defer { cleanup(path) }

            let filePath = try File.Path(path)

            let result = try await File.Handle.withOpen(filePath, mode: .read) { handle async throws in
                // Simulate async work
                try await Task.sleep(for: .milliseconds(1))
                return try handle.read(count: 10)
            }

            #expect(result == content)
        }
    }
}
