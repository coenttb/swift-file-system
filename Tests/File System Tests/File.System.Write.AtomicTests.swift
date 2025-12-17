// File.System.Write.AtomicTests.swift

import Testing
@testable import File_System

@Suite("File.System.Write.Atomic Tests")
struct FileSystemWriteAtomicTests {

    @Test("Write and read back bytes")
    func writeAndReadBytes() throws {
        let tempDir = "/tmp"
        let path = "\(tempDir)/atomic-test-\(UInt64.random(in: 0...UInt64.max)).txt"

        defer {
            try? FileManager.default.removeItem(atPath: path)
        }

        let testData: [UInt8] = [72, 101, 108, 108, 111]  // "Hello"

        try File.System.Write.Atomic.write(testData, to: path)

        // Verify file exists and has correct content
        let readData = try [UInt8](Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(readData == testData)
    }

    @Test("Empty file write")
    func emptyFileWrite() throws {
        let tempDir = "/tmp"
        let path = "\(tempDir)/atomic-empty-\(UInt64.random(in: 0...UInt64.max)).txt"

        defer {
            try? FileManager.default.removeItem(atPath: path)
        }

        try File.System.Write.Atomic.write([], to: path)

        let readData = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(readData.isEmpty)
    }

    @Test("Invalid path - empty")
    func invalidPathEmpty() {
        #expect(throws: File.System.Write.Atomic.Error.self) {
            try File.System.Write.Atomic.write([1, 2, 3], to: "")
        }
    }

    @Test("Invalid path - contains control characters")
    func invalidPathControlCharacters() {
        #expect(throws: File.System.Write.Atomic.Error.self) {
            try File.System.Write.Atomic.write([1, 2, 3], to: "/tmp/test\0file.txt")
        }
    }

    @Test("NoClobber strategy prevents overwrite")
    func noClobberPreventsOverwrite() throws {
        let tempDir = "/tmp"
        let path = "\(tempDir)/atomic-noclobber-\(UInt64.random(in: 0...UInt64.max)).txt"

        defer {
            try? FileManager.default.removeItem(atPath: path)
        }

        // First write should succeed
        try File.System.Write.Atomic.write([1, 2, 3], to: path)

        // Second write with noClobber should fail
        let options = File.System.Write.Atomic.Options(strategy: .noClobber)
        #expect(throws: File.System.Write.Atomic.Error.self) {
            try File.System.Write.Atomic.write([4, 5, 6], to: path, options: options)
        }
    }

    @Test("Replace existing file")
    func replaceExistingFile() throws {
        let tempDir = "/tmp"
        let path = "\(tempDir)/atomic-replace-\(UInt64.random(in: 0...UInt64.max)).txt"

        defer {
            try? FileManager.default.removeItem(atPath: path)
        }

        // First write
        try File.System.Write.Atomic.write([1, 2, 3], to: path)

        // Second write should replace
        let newData: [UInt8] = [4, 5, 6, 7, 8]
        try File.System.Write.Atomic.write(newData, to: path)

        let readData = try [UInt8](Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(readData == newData)
    }
}

// Import Foundation for test utilities only
import Foundation
