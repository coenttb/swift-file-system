//
//  File.Directory.Entries.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
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

extension File.Directory {
    /// An async sequence of directory entries.
    ///
    /// This provides lazy iteration over directory contents. Entries are
    /// yielded one at a time, making it memory-efficient for large directories.
    ///
    /// ## Example
    /// ```swift
    /// let entries = try File.Directory.Entries(at: path)
    /// for try await entry in entries {
    ///     print(entry.name)
    /// }
    /// ```
    public struct Entries: AsyncSequence, Sendable {
        public typealias Element = File.Directory.Entry

        /// The path being iterated.
        public let path: File.Path

        /// Creates an entries sequence for the given path.
        ///
        /// - Parameter path: The directory path to iterate.
        public init(at path: File.Path) {
            self.path = path
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(path: path)
        }
    }
}

// MARK: - AsyncIterator

extension File.Directory.Entries {
    /// The async iterator for directory entries.
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let path: File.Path
        private var state: IteratorState

        init(path: File.Path) {
            self.path = path
            self.state = .notStarted
        }

        public mutating func next() async throws -> File.Directory.Entry? {
            switch state {
            case .notStarted:
                let handle = try openDirectory(at: path)
                state = .iterating(handle)
                return try await self.next()

            case .iterating(let handle):
                if let entry = try readNextEntry(from: handle, basePath: path) {
                    return entry
                } else {
                    closeDirectory(handle)
                    state = .finished
                    return nil
                }

            case .finished:
                return nil
            }
        }
    }
}

// MARK: - Iterator State

extension File.Directory.Entries.AsyncIterator {
    private enum IteratorState: @unchecked Sendable {
        case notStarted
        #if os(Windows)
        case iterating(DirectoryHandle)
        #else
        case iterating(DirectoryHandle)
        #endif
        case finished
    }

    #if os(Windows)
    private final class DirectoryHandle: @unchecked Sendable {
        var handle: HANDLE?
        var findData: WIN32_FIND_DATAW
        var hasMore: Bool

        init(handle: HANDLE, findData: WIN32_FIND_DATAW) {
            self.handle = handle
            self.findData = findData
            self.hasMore = true
        }

        deinit {
            if let h = handle, h != INVALID_HANDLE_VALUE {
                FindClose(h)
            }
        }
    }
    #else
    private final class DirectoryHandle: @unchecked Sendable {
        var dir: UnsafeMutablePointer<DIR>?

        init(dir: UnsafeMutablePointer<DIR>) {
            self.dir = dir
        }

        deinit {
            if let d = dir {
                closedir(d)
            }
        }
    }
    #endif
}

// MARK: - Platform-specific implementation

extension File.Directory.Entries.AsyncIterator {
    #if os(Windows)
    private func openDirectory(at path: File.Path) throws -> DirectoryHandle {
        var findData = WIN32_FIND_DATAW()
        let searchPath = path.string + "\\*"

        let handle = searchPath.withCString(encodedAs: UTF16.self) { wpath in
            FindFirstFileW(wpath, &findData)
        }

        guard handle != INVALID_HANDLE_VALUE else {
            throw File.Directory.Iterator.Error.pathNotFound(path)
        }

        return DirectoryHandle(handle: handle, findData: findData)
    }

    private func readNextEntry(from handle: DirectoryHandle, basePath: File.Path) throws -> File.Directory.Entry? {
        guard let h = handle.handle, h != INVALID_HANDLE_VALUE, handle.hasMore else {
            return nil
        }

        while true {
            let name = String(windowsDirectoryEntryName: handle.findData.cFileName)

            // Advance to next entry
            if !FindNextFileW(h, &handle.findData) {
                handle.hasMore = false
            }

            // Skip . and ..
            if name == "." || name == ".." {
                if !handle.hasMore { return nil }
                continue
            }

            // Build full path using proper path composition
            let entryPath = basePath.appending(name)

            // Determine type
            let entryType: File.Directory.EntryType
            if (handle.findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0 {
                entryType = .directory
            } else if (handle.findData.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
                entryType = .symbolicLink
            } else {
                entryType = .file
            }

            return File.Directory.Entry(name: name, path: entryPath, type: entryType)
        }
    }

    private func closeDirectory(_ handle: DirectoryHandle) {
        if let h = handle.handle, h != INVALID_HANDLE_VALUE {
            FindClose(h)
            handle.handle = nil
        }
    }

    #else
    private func openDirectory(at path: File.Path) throws -> DirectoryHandle {
        guard let dir = opendir(path.string) else {
            let err = errno
            switch err {
            case ENOENT:
                throw File.Directory.Iterator.Error.pathNotFound(path)
            case EACCES, EPERM:
                throw File.Directory.Iterator.Error.permissionDenied(path)
            case ENOTDIR:
                throw File.Directory.Iterator.Error.notADirectory(path)
            default:
                throw File.Directory.Iterator.Error.readFailed(errno: err, message: String(cString: strerror(err)))
            }
        }
        return DirectoryHandle(dir: dir)
    }

    private func readNextEntry(from handle: DirectoryHandle, basePath: File.Path) throws -> File.Directory.Entry? {
        guard let dir = handle.dir else {
            return nil
        }

        while let entry = readdir(dir) {
            let name = String(posixDirectoryEntryName: entry.pointee.d_name)

            // Skip . and ..
            if name == "." || name == ".." {
                continue
            }

            // Build full path using proper path composition
            let entryPath = basePath.appending(name)

            // Determine type
            let entryType: File.Directory.EntryType
            #if canImport(Darwin)
            switch Int32(entry.pointee.d_type) {
            case DT_REG:
                entryType = .file
            case DT_DIR:
                entryType = .directory
            case DT_LNK:
                entryType = .symbolicLink
            default:
                entryType = .other
            }
            #else
            var entryStat = stat()
            if lstat(entryPath.string, &entryStat) == 0 {
                switch entryStat.st_mode & S_IFMT {
                case S_IFREG:
                    entryType = .file
                case S_IFDIR:
                    entryType = .directory
                case S_IFLNK:
                    entryType = .symbolicLink
                default:
                    entryType = .other
                }
            } else {
                entryType = .other
            }
            #endif

            return File.Directory.Entry(name: name, path: entryPath, type: entryType)
        }

        return nil
    }

    private func closeDirectory(_ handle: DirectoryHandle) {
        if let d = handle.dir {
            closedir(d)
            handle.dir = nil
        }
    }
    #endif
}
