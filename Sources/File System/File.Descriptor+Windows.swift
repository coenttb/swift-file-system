//
//  File.Descriptor+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

import WinSDK

extension File.Descriptor {
    /// Opens a file using Windows APIs.
    @usableFromInline
    internal static func _openWindows(
        _ path: File.Path,
        mode: Mode,
        options: Options
    ) throws(Error) -> File.Descriptor {
        var desiredAccess: DWORD = 0
        var shareMode: DWORD = FILE_SHARE_READ | FILE_SHARE_WRITE
        var creationDisposition: DWORD = OPEN_EXISTING
        var flagsAndAttributes: DWORD = FILE_ATTRIBUTE_NORMAL

        // Set access mode
        switch mode {
        case .read:
            desiredAccess = GENERIC_READ
        case .write:
            desiredAccess = GENERIC_WRITE
        case .readWrite:
            desiredAccess = GENERIC_READ | GENERIC_WRITE
        }

        // Set creation disposition based on options
        if options.contains(.create) {
            if options.contains(.exclusive) {
                creationDisposition = CREATE_NEW
            } else if options.contains(.truncate) {
                creationDisposition = CREATE_ALWAYS
            } else {
                creationDisposition = OPEN_ALWAYS
            }
        } else if options.contains(.truncate) {
            creationDisposition = TRUNCATE_EXISTING
        }

        // Append mode
        if options.contains(.append) {
            desiredAccess = FILE_APPEND_DATA
        }

        // No follow symlinks
        if options.contains(.noFollow) {
            flagsAndAttributes |= FILE_FLAG_OPEN_REPARSE_POINT
        }

        let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
            CreateFileW(
                wpath,
                desiredAccess,
                shareMode,
                nil,
                creationDisposition,
                flagsAndAttributes,
                nil
            )
        }

        guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
            throw _mapWindowsError(GetLastError(), path: path)
        }

        return File.Descriptor(__unchecked: handle)
    }

    /// Maps Windows error code to a descriptor error.
    @usableFromInline
    internal static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
        switch error {
        case DWORD(ERROR_FILE_NOT_FOUND), DWORD(ERROR_PATH_NOT_FOUND):
            return .pathNotFound(path)
        case DWORD(ERROR_ACCESS_DENIED):
            return .permissionDenied(path)
        case DWORD(ERROR_FILE_EXISTS), DWORD(ERROR_ALREADY_EXISTS):
            return .alreadyExists(path)
        case DWORD(ERROR_TOO_MANY_OPEN_FILES):
            return .tooManyOpenFiles
        default:
            return .openFailed(errno: Int32(error), message: "Windows error \(error)")
        }
    }
}

#endif
