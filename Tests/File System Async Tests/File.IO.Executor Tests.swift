//
//  File.IO.Executor Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing
@testable import File_System_Async
import Foundation

extension File.System.Async.Test.Unit {
    @Suite("File.IO.Executor")
    struct Executor {

        // MARK: - Basic Execution

        @Test("Execute simple operation")
        func executeSimple() async throws {
            let executor = File.IO.Executor()
            let result = try await executor.run { 42 }
            #expect(result == 42)
            await executor.shutdown()
        }

        @Test("Execute throwing operation")
        func executeThrowing() async throws {
            let executor = File.IO.Executor()

            struct TestError: Error {}

            await #expect(throws: TestError.self) {
                try await executor.run { throw TestError() }
            }
            await executor.shutdown()
        }

        @Test("Execute multiple operations")
        func executeMultiple() async throws {
            let executor = File.IO.Executor()

            let results = try await withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        try await executor.run { i * 2 }
                    }
                }
                var results: [Int] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted()
            }

            #expect(results == [0, 2, 4, 6, 8, 10, 12, 14, 16, 18])
            await executor.shutdown()
        }

        // MARK: - Shutdown

        @Test("Run after shutdown throws")
        func runAfterShutdown() async throws {
            let executor = File.IO.Executor()
            await executor.shutdown()

            await #expect(throws: File.IO.ExecutorError.self) {
                try await executor.run { 42 }
            }
        }

        @Test("Shutdown is idempotent")
        func shutdownIdempotent() async throws {
            let executor = File.IO.Executor()
            await executor.shutdown()
            await executor.shutdown()  // Should not hang or crash
        }

        @Test("In-flight jobs complete during shutdown")
        func inFlightCompletesDuringShutdown() async throws {
            let executor = File.IO.Executor(.init(workers: 1))
            let started = ManagedAtomic(false)
            let completed = ManagedAtomic(false)

            // Start a long-running job
            let task = Task {
                try await executor.run {
                    started.store(true, ordering: .releasing)
                    Thread.sleep(forTimeInterval: 0.1)
                    completed.store(true, ordering: .releasing)
                    return 42
                }
            }

            // Wait for job to start
            while !started.load(ordering: .acquiring) {
                await Task.yield()
            }

            // Shutdown while job is in-flight
            await executor.shutdown()

            // Job should have completed
            #expect(completed.load(ordering: .acquiring))

            // Task should return successfully
            let result = try await task.value
            #expect(result == 42)
        }

        // MARK: - Configuration

        @Test("Configuration default values")
        func configurationDefaults() {
            let config = File.IO.Configuration()
            #expect(config.workers == File.IO.Configuration.defaultWorkerCount)
            #expect(config.queueLimit == 10_000)
        }

        @Test("Configuration custom values")
        func configurationCustom() {
            let config = File.IO.Configuration(workers: 4, queueLimit: 100)
            #expect(config.workers == 4)
            #expect(config.queueLimit == 100)
        }

        @Test("Configuration enforces minimum values")
        func configurationMinimums() {
            let config = File.IO.Configuration(workers: 0, queueLimit: 0)
            #expect(config.workers >= 1)
            #expect(config.queueLimit >= 1)
        }

        @Test("Configuration default thread model is cooperative")
        func configurationDefaultThreadModel() {
            let config = File.IO.Configuration()
            #expect(config.threadModel == .cooperative)
        }

        @Test("Configuration custom thread model")
        func configurationCustomThreadModel() {
            let config = File.IO.Configuration(threadModel: .dedicated)
            #expect(config.threadModel == .dedicated)
        }

        // MARK: - Thread Model Tests

        @Test("Execute with cooperative thread model")
        func executeWithCooperativeThreadModel() async throws {
            let config = File.IO.Configuration(workers: 2, threadModel: .cooperative)
            let executor = File.IO.Executor(config)

            let results = try await withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        try await executor.run { i * 2 }
                    }
                }
                var results: [Int] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted()
            }

            #expect(results == [0, 2, 4, 6, 8, 10, 12, 14, 16, 18])
            await executor.shutdown()
        }

        @Test("Execute with dedicated thread model")
        func executeWithDedicatedThreadModel() async throws {
            let config = File.IO.Configuration(workers: 2, threadModel: .dedicated)
            let executor = File.IO.Executor(config)

            let results = try await withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        try await executor.run { i * 2 }
                    }
                }
                var results: [Int] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted()
            }

            #expect(results == [0, 2, 4, 6, 8, 10, 12, 14, 16, 18])
            await executor.shutdown()
        }

        @Test("Dedicated thread model handles blocking operations")
        func dedicatedThreadModelBlockingOps() async throws {
            let config = File.IO.Configuration(workers: 2, threadModel: .dedicated)
            let executor = File.IO.Executor(config)

            // Simulate blocking I/O operations
            let results = try await withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<5 {
                    group.addTask {
                        try await executor.run {
                            // Simulate blocking I/O
                            Thread.sleep(forTimeInterval: 0.01)
                            return i
                        }
                    }
                }
                var results: [Int] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted()
            }

            #expect(results == [0, 1, 2, 3, 4])
            await executor.shutdown()
        }

        @Test("Both thread models produce equivalent results")
        func threadModelEquivalence() async throws {
            let cooperativeConfig = File.IO.Configuration(workers: 2, threadModel: .cooperative)
            let dedicatedConfig = File.IO.Configuration(workers: 2, threadModel: .dedicated)

            let cooperativeExecutor = File.IO.Executor(cooperativeConfig)
            let dedicatedExecutor = File.IO.Executor(dedicatedConfig)

            // Run same operations on both executors
            async let cooperativeResults = withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        try await cooperativeExecutor.run { i * 3 }
                    }
                }
                var results: [Int] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted()
            }

            async let dedicatedResults = withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        try await dedicatedExecutor.run { i * 3 }
                    }
                }
                var results: [Int] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted()
            }

            let (coop, dedicated) = try await (cooperativeResults, dedicatedResults)
            #expect(coop == dedicated)
            #expect(coop == [0, 3, 6, 9, 12, 15, 18, 21, 24, 27])

            await cooperativeExecutor.shutdown()
            await dedicatedExecutor.shutdown()
        }
    }
}

// Simple atomic for testing
private final class ManagedAtomic<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) {
        self._value = value
    }

    func load(ordering: MemoryOrder) -> T {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func store(_ value: T, ordering: MemoryOrder) {
        lock.lock()
        defer { lock.unlock() }
        _value = value
    }

    enum MemoryOrder {
        case acquiring, releasing
    }
}
