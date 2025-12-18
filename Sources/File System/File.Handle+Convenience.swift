//
//  File.Handle+Convenience.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Handle {
    /// Opens a file, runs a closure, and ensures the handle is closed.
    ///
    /// This convenience method handles resource cleanup automatically,
    /// ensuring the file handle is closed when the closure completes,
    /// whether normally or by throwing an error.
    ///
    /// ## Example
    /// ```swift
    /// let content = try File.Handle.withOpen(path, mode: .read) { handle in
    ///     try handle.read(count: 1024)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: A closure that receives an inout handle and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Error` on open failure, or any error thrown by the closure.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Handle) throws -> Result
    ) throws -> Result {
        var handle = try open(path, mode: mode, options: options)
        do {
            let result = try body(&handle)
            handle.close()
            return result
        } catch {
            handle.close()
            throw error
        }
    }

    /// Opens a file, runs an async closure, and ensures the handle is closed.
    ///
    /// This is the async variant of `withOpen` for use in async contexts.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: An async closure that receives an inout handle and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Error` on open failure, or any error thrown by the closure.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Handle) async throws -> Result
    ) async throws -> Result {
        var handle = try open(path, mode: mode, options: options)
        do {
            let result = try await body(&handle)
            handle.close()
            return result
        } catch {
            handle.close()
            throw error
        }
    }
}
