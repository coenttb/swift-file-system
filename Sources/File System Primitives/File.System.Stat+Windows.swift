//
//  File.System.Stat+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

import WinSDK

extension File.System.Stat {
    /// Gets file info using Windows APIs.
    @usableFromInline
    internal static func _infoWindows(at path: File.Path) throws(Error) -> File.System.Metadata.Info {
        var findData = WIN32_FIND_DATAW()

        let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
            FindFirstFileW(wpath, &findData)
        }

        guard handle != INVALID_HANDLE_VALUE else {
            throw _mapWindowsError(GetLastError(), path: path)
        }
        FindClose(handle)

        return _makeInfo(from: findData)
    }

    /// Checks if path exists using Windows APIs.
    @usableFromInline
    internal static func _existsWindows(at path: File.Path) -> Bool {
        let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
            GetFileAttributesW(wpath)
        }
        return attrs != INVALID_FILE_ATTRIBUTES
    }

    /// Checks if path is a symlink using Windows APIs.
    @usableFromInline
    internal static func _isSymlinkWindows(at path: File.Path) -> Bool {
        let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
            GetFileAttributesW(wpath)
        }
        guard attrs != INVALID_FILE_ATTRIBUTES else { return false }
        return (attrs & FILE_ATTRIBUTE_REPARSE_POINT) != 0
    }

    /// Creates Info from Windows find data.
    @usableFromInline
    internal static func _makeInfo(from data: WIN32_FIND_DATAW) -> File.System.Metadata.Info {
        let fileType: File.System.Metadata.FileType
        if (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0 {
            fileType = .directory
        } else if (data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
            fileType = .symbolicLink
        } else {
            fileType = .regular
        }

        // Windows doesn't have POSIX permissions, default to 644
        let permissions = File.System.Metadata.Permissions.defaultFile

        // Windows doesn't expose uid/gid
        let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

        let size = Int64(data.nFileSizeHigh) << 32 | Int64(data.nFileSizeLow)

        let timestamps = File.System.Metadata.Timestamps(
            accessTime: _fileTimeToUnix(data.ftLastAccessTime),
            modificationTime: _fileTimeToUnix(data.ftLastWriteTime),
            changeTime: _fileTimeToUnix(data.ftLastWriteTime),
            creationTime: _fileTimeToUnix(data.ftCreationTime)
        )

        return File.System.Metadata.Info(
            size: size,
            permissions: permissions,
            owner: ownership,
            timestamps: timestamps,
            type: fileType,
            inode: 0, // Windows doesn't have inodes
            deviceId: 0,
            linkCount: 1
        )
    }

    /// Converts Windows FILETIME to Unix timestamp.
    @usableFromInline
    internal static func _fileTimeToUnix(_ ft: FILETIME) -> Int64 {
        let ticks = Int64(ft.dwHighDateTime) << 32 | Int64(ft.dwLowDateTime)
        // FILETIME is 100-nanosecond intervals since Jan 1, 1601
        // Unix epoch is Jan 1, 1970
        // Difference is 11644473600 seconds
        return (ticks / 10_000_000) - 11644473600
    }

    /// Maps Windows error to stat error.
    @usableFromInline
    internal static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
        switch error {
        case DWORD(ERROR_FILE_NOT_FOUND), DWORD(ERROR_PATH_NOT_FOUND):
            return .pathNotFound(path)
        case DWORD(ERROR_ACCESS_DENIED):
            return .permissionDenied(path)
        default:
            return .statFailed(errno: Int32(error), message: "Windows error \(error)")
        }
    }
}

#endif
