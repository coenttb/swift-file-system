//
//  File.System.Copy+POSIX.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if !os(Windows)

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension File.System.Copy {
    /// Copies a file using POSIX APIs.
    internal static func _copyPOSIX(
        from source: File.Path,
        to destination: File.Path,
        options: Options
    ) throws(Error) {
        // Stat source
        var sourceStat = stat()
        let statResult: Int32
        if options.followSymlinks {
            statResult = stat(source.string, &sourceStat)
        } else {
            statResult = lstat(source.string, &sourceStat)
        }

        guard statResult == 0 else {
            throw _mapErrno(errno, source: source, destination: destination)
        }

        // Check if source is a directory
        if (sourceStat.st_mode & S_IFMT) == S_IFDIR {
            throw .isDirectory(source)
        }

        // Check if destination exists
        var destStat = stat()
        let destExists = stat(destination.string, &destStat) == 0

        if destExists && !options.overwrite {
            throw .destinationExists(destination)
        }

        // Open source for reading
        let srcFd = open(source.string, O_RDONLY)
        guard srcFd >= 0 else {
            throw _mapErrno(errno, source: source, destination: destination)
        }
        defer { _ = close(srcFd) }

        // Create/truncate destination
        let dstFlags: Int32 = O_WRONLY | O_CREAT | O_TRUNC
        let dstMode = sourceStat.st_mode & 0o7777
        let dstFd = open(destination.string, dstFlags, dstMode)
        guard dstFd >= 0 else {
            throw _mapErrno(errno, source: source, destination: destination)
        }

        var success = false
        defer {
            _ = close(dstFd)
            if !success {
                _ = unlink(destination.string)
            }
        }

        // Copy data
        let bufferSize = 64 * 1024 // 64KB buffer
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while true {
            #if canImport(Darwin)
            let bytesRead = buffer.withUnsafeMutableBufferPointer { ptr in
                Darwin.read(srcFd, ptr.baseAddress!, bufferSize)
            }
            #elseif canImport(Glibc)
            let bytesRead = buffer.withUnsafeMutableBufferPointer { ptr in
                Glibc.read(srcFd, ptr.baseAddress!, bufferSize)
            }
            #elseif canImport(Musl)
            let bytesRead = buffer.withUnsafeMutableBufferPointer { ptr in
                Musl.read(srcFd, ptr.baseAddress!, bufferSize)
            }
            #endif

            if bytesRead < 0 {
                if errno == EINTR { continue }
                throw _mapErrno(errno, source: source, destination: destination)
            }
            if bytesRead == 0 { break } // EOF

            var written = 0
            while written < bytesRead {
                let w = buffer.withUnsafeBufferPointer { ptr in
                    write(dstFd, ptr.baseAddress!.advanced(by: written), bytesRead - written)
                }
                if w < 0 {
                    if errno == EINTR { continue }
                    throw _mapErrno(errno, source: source, destination: destination)
                }
                written += w
            }
        }

        // Copy attributes if requested
        if options.copyAttributes {
            // Copy permissions
            _ = fchmod(dstFd, sourceStat.st_mode & 0o7777)

            // Copy timestamps
            #if canImport(Darwin)
            var times = [
                timespec(tv_sec: sourceStat.st_atimespec.tv_sec, tv_nsec: sourceStat.st_atimespec.tv_nsec),
                timespec(tv_sec: sourceStat.st_mtimespec.tv_sec, tv_nsec: sourceStat.st_mtimespec.tv_nsec)
            ]
            #else
            var times = [
                timespec(tv_sec: sourceStat.st_atim.tv_sec, tv_nsec: sourceStat.st_atim.tv_nsec),
                timespec(tv_sec: sourceStat.st_mtim.tv_sec, tv_nsec: sourceStat.st_mtim.tv_nsec)
            ]
            #endif
            _ = futimens(dstFd, &times)
        }

        success = true
    }

    /// Maps errno to copy error.
    private static func _mapErrno(_ errno: Int32, source: File.Path, destination: File.Path) -> Error {
        switch errno {
        case ENOENT:
            return .sourceNotFound(source)
        case EEXIST:
            return .destinationExists(destination)
        case EACCES, EPERM:
            return .permissionDenied(source)
        case EISDIR:
            return .isDirectory(source)
        default:
            let message: String
            if let cString = strerror(errno) {
                message = String(cString: cString)
            } else {
                message = "Unknown error"
            }
            return .copyFailed(errno: errno, message: message)
        }
    }
}

#endif
