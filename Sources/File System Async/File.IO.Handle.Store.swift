//
//  File.IO.Handle.Store.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Foundation

// MARK: - Atomic Counter

/// Simple thread-safe counter for generating unique IDs.
final class _AtomicCounter: @unchecked Sendable {
    private var value: UInt64 = 0
    private let lock = NSLock()

    func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        let result = value
        value += 1
        return result
    }
}

// MARK: - HandleID

extension File.IO {
    /// A unique identifier for a registered file handle.
    ///
    /// HandleIDs are:
    /// - Scoped to a specific executor/store instance (prevents cross-executor misuse)
    /// - Never reused within an executor's lifetime
    /// - Sendable and Hashable for use as dictionary keys
    public struct HandleID: Hashable, Sendable {
        /// The unique identifier within the store.
        let raw: UInt64
        /// The scope identifier (unique per store instance).
        let scope: UInt64
    }
}

// MARK: - Handle Errors

extension File.IO {
    /// Errors related to handle operations in the store.
    public enum HandleError: Error, Sendable {
        /// The handle ID does not exist in the store (already closed or never existed).
        case invalidHandleID
        /// The handle ID belongs to a different executor/store.
        case scopeMismatch
        /// The handle has already been closed.
        case handleClosed
    }
}

// MARK: - HandleBox

extension File.IO {
    /// A heap-allocated box that owns a File.Handle with its own lock.
    ///
    /// This design enables:
    /// - Per-handle locking (parallelism across different handles)
    /// - Stable storage address (dictionary rehashing doesn't invalidate inout)
    /// - Safe concurrent access patterns
    ///
    /// ## Implementation Note
    /// Uses `UnsafeMutablePointer` for storage because Swift 6 does not allow
    /// moving a ~Copyable value out of a class stored property. The pointer
    /// provides a stable address for inout access.
    final class HandleBox: @unchecked Sendable {
        /// Lock protecting the handle.
        private let lock = NSLock()
        /// Pointer to the handle storage. Nil means closed.
        private var storage: UnsafeMutablePointer<File.Handle>?
        /// The path (for diagnostics).
        let path: File.Path
        /// The mode (for diagnostics).
        let mode: File.Handle.Mode

        init(_ handle: consuming File.Handle) {
            self.path = handle.path
            self.mode = handle.mode
            // Allocate and initialize storage
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume handle)
        }

        deinit {
            // If storage still exists, we need to clean up
            if let ptr = storage {
                // Move out and close
                let handle = ptr.move()
                ptr.deallocate()
                _ = try? handle.close()
            }
        }

        /// Whether the handle is still open.
        var isOpen: Bool {
            lock.lock()
            defer { lock.unlock() }
            return storage != nil
        }

        /// Execute a closure with exclusive access to the handle.
        ///
        /// - Parameter body: Closure receiving inout access to the handle.
        /// - Returns: The result of the closure.
        /// - Throws: `HandleError.handleClosed` if handle was already closed.
        func withHandle<T>(_ body: (inout File.Handle) throws -> T) throws -> T {
            lock.lock()
            defer { lock.unlock() }

            guard let ptr = storage else {
                throw HandleError.handleClosed
            }

            // Access via pointer - stable address, no move required
            return try body(&ptr.pointee)
        }

        /// Close the handle and return any error.
        ///
        /// - Returns: The close error, if any.
        /// - Note: Idempotent - second call returns nil.
        func close() -> (any Error)? {
            lock.lock()
            defer { lock.unlock() }

            guard let ptr = storage else {
                return nil  // Already closed
            }

            // Move out, deallocate, close
            let handle = ptr.move()
            ptr.deallocate()
            storage = nil

            do {
                try handle.close()
                return nil
            } catch {
                return error
            }
        }
    }
}

// MARK: - Handle Store

extension File.IO {
    /// Thread-safe storage for file handles, owned by an executor.
    ///
    /// ## Design
    /// - Dictionary maps HandleID → HandleBox
    /// - Dictionary lock guards map mutations only
    /// - Per-handle locks (in HandleBox) guard handle operations
    /// - This enables parallelism across different handles
    ///
    /// ## Lifecycle
    /// - Store lifetime = Executor lifetime
    /// - Shutdown forcibly closes remaining handles
    final class HandleStore: @unchecked Sendable {
        /// Lock protecting the dictionary.
        private let mapLock = NSLock()
        /// The handle storage.
        private var handles: [HandleID: HandleBox] = [:]
        /// Counter for generating unique IDs.
        private var nextID: UInt64 = 0
        /// Unique scope identifier for this store instance.
        let scope: UInt64
        /// Whether the store has been shut down.
        private var isShutdown: Bool = false

        /// Global counter for generating unique scope IDs.
        private static let scopeCounter = _AtomicCounter()

        init() {
            // Generate a unique scope ID for this store instance
            self.scope = Self.scopeCounter.next()
        }

        /// Register a handle and return its ID.
        ///
        /// - Parameter handle: The handle to register (ownership transferred).
        /// - Returns: The handle ID for future operations.
        /// - Throws: `ExecutorError.shutdownInProgress` if store is shut down.
        func register(_ handle: consuming File.Handle) throws -> HandleID {
            mapLock.lock()
            defer { mapLock.unlock() }

            guard !isShutdown else {
                // Close the handle we were given since we can't store it
                _ = try? handle.close()
                throw ExecutorError.shutdownInProgress
            }

            let id = HandleID(raw: nextID, scope: scope)
            nextID += 1

            let box = HandleBox(handle)
            handles[id] = box

            return id
        }

        /// Execute a closure with exclusive access to a handle.
        ///
        /// - Parameters:
        ///   - id: The handle ID.
        ///   - body: Closure receiving inout access to the handle.
        /// - Returns: The result of the closure.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different store.
        /// - Throws: `HandleError.invalidHandleID` if ID not found.
        /// - Throws: `HandleError.handleClosed` if handle was closed.
        func withHandle<T>(_ id: HandleID, _ body: (inout File.Handle) throws -> T) throws -> T {
            // Validate scope first
            guard id.scope == scope else {
                throw HandleError.scopeMismatch
            }

            // Find the box (short lock)
            mapLock.lock()
            let box = handles[id]
            mapLock.unlock()

            guard let box else {
                throw HandleError.invalidHandleID
            }

            // Execute with per-handle lock
            return try box.withHandle(body)
        }

        /// Close and remove a handle.
        ///
        /// - Parameter id: The handle ID.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different store.
        /// - Throws: Close errors from the underlying handle.
        /// - Note: Idempotent for same-scope IDs that were already closed.
        func destroy(_ id: HandleID) throws {
            // Validate scope first - scope mismatch is always an error
            guard id.scope == scope else {
                throw HandleError.scopeMismatch
            }

            // Remove from dictionary (short lock)
            mapLock.lock()
            let box = handles.removeValue(forKey: id)
            mapLock.unlock()

            // If not found, treat as already closed (idempotent)
            guard let box else {
                return
            }

            // Close the handle (may throw)
            if let error = box.close() {
                throw error
            }
        }

        /// Shutdown the store: close all remaining handles.
        ///
        /// - Note: Close errors are logged but not propagated.
        /// - Postcondition: All handles closed, store rejects new registrations.
        func shutdown() {
            mapLock.lock()
            isShutdown = true
            let remainingHandles = handles
            handles.removeAll()
            mapLock.unlock()

            // Close all remaining handles (best-effort)
            for (id, box) in remainingHandles {
                if let error = box.close() {
                    #if DEBUG
                    print("Warning: Error closing handle \(id.raw) during shutdown: \(error)")
                    #endif
                }
            }
        }

        /// Check if a handle ID is valid (for diagnostics).
        func isValid(_ id: HandleID) -> Bool {
            guard id.scope == scope else { return false }
            mapLock.lock()
            defer { mapLock.unlock() }
            return handles[id] != nil
        }

        /// The number of registered handles (for testing).
        var count: Int {
            mapLock.lock()
            defer { mapLock.unlock() }
            return handles.count
        }
    }
}
