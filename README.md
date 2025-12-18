# swift-file-system

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Type-safe file system operations for Swift with kernel-assisted I/O and async streaming. Zero-copy APFS clones, batched directory iteration (48x speedup), and configurable durability. Swift 6 strict concurrency with actor-based I/O executor.

## Table of Contents

- [Why swift-file-system?](#why-swift-file-system)
- [Overview](#overview)
- [Design Guarantees](#design-guarantees)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [Performance](#performance)
- [Architecture](#architecture)
- [Platform Support](#platform-support)
- [Non-goals](#non-goals)
- [Testing](#testing)
- [Related Packages](#related-packages)
- [Contributing](#contributing)
- [License](#license)

## Why swift-file-system?

Foundation's `FileManager` and `URL` APIs are designed for simplicity, not performance or async correctness. This library exists to solve problems Foundation cannot:

| Problem | Foundation | swift-file-system |
|---------|------------|-------------------|
| **Async iteration** | Blocks thread per entry | Batched async with 48x fewer executor hops |
| **File copy** | Always reads+writes bytes | APFS clone (0.2ms), kernel-assisted paths |
| **Durability control** | No control over fsync | `.full`, `.dataOnly`, `.none` modes |
| **Thread pool starvation** | Blocking I/O starves cooperative pool | Dedicated executor option isolates I/O |
| **Concurrency safety** | Requires manual synchronization | `Sendable` throughout, actor-isolated state |
| **Symlink handling** | Implicit, inconsistent | Explicit `followSymlinks` option everywhere |

If you need predictable async behavior, kernel-level optimizations, or fine-grained durability control, this library provides what Foundation cannot.

## Overview

swift-file-system provides a modern Swift interface for file system operations with focus on performance, safety, and async-first design. Built on POSIX and Windows APIs with platform-specific optimizations like APFS cloning on macOS and `copy_file_range`/`sendfile` on Linux.

## Design Guarantees

### What this library guarantees

- **Atomic writes**: Write-sync-rename pattern ensures no partial writes on crash (when durability is `.full` or `.dataOnly`)
- **Bounded memory**: Async executor queue is bounded; backpressure suspends callers when full
- **Fallback correctness**: Copy operations try fast paths first, fall back gracefully to manual loop
- **No data races**: Full Swift 6 strict concurrency compliance with `Sendable` types throughout
- **Graceful shutdown**: In-flight operations complete; pending operations fail with explicit error

### What this library does NOT guarantee

- **Cross-process consistency**: No file locking primitives (yet); concurrent access from multiple processes requires external coordination
- **Path normalization**: `File.Path` validates structure (no NUL bytes, no empty components) but does not resolve `..`, symlinks, or canonicalize case
- **Windows path semantics**: UNC paths (`\\server\share`) and drive-relative paths (`C:foo`) are not fully validated
- **Security sandbox**: This is not a security boundary; path traversal prevention is best-effort, not hardened

Use `File.Path` for structured path manipulation, but do not rely on it as a security mechanism.

## Features

- **Kernel-assisted file copy**: APFS cloning (0.2ms for 100MB), `copyfile()` on Darwin, `copy_file_range`/`sendfile` on Linux
- **Batched directory iteration**: 48x speedup by reducing executor hops from N to N/64
- **Async streaming**: `AsyncSequence` for file bytes, directory entries, and recursive walks
- **Atomic writes**: Crash-safe write-sync-rename pattern with configurable durability modes
- **Dedicated I/O executor**: Actor-based thread pool that doesn't starve Swift's cooperative pool
- **Validated paths**: `File.Path` rejects NUL bytes, empty components, and embedded newlines
- **Swift 6 strict concurrency**: Full `Sendable` compliance, no data races
- **Cross-platform**: macOS, iOS, Linux, and Windows support

## Installation

Add swift-file-system to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-file-system.git", from: "0.1.0")
]
```

Add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "File System", package: "swift-file-system"),
        .product(name: "File System Async", package: "swift-file-system"),
    ]
)
```

### Requirements

- Swift 6.2+
- macOS 26.0+, iOS 26.0+, or Linux
- Xcode 26.0+ (for Apple platforms)

## Quick Start

### Synchronous API

```swift
import FileSystem

// Read file
let data = try File.System.Read.Full.read(from: path)

// Write file atomically
try File.System.Write.Atomic.write(data, to: path)

// Copy with APFS clone (instant on same filesystem)
try File.System.Copy.copy(from: source, to: destination)

// Iterate directory
for entry in try File.Directory.Contents(at: directoryPath) {
    print(entry.name)
}

// Recursive walk
for entry in try File.Directory.Walk(at: rootPath) {
    print("\(entry.depth): \(entry.path)")
}
```

### Async API

```swift
import FileSystemAsync

let io = File.IO.Executor()

// Stream file bytes
for try await byte in File.Stream.Async(io: io).bytes(from: path) {
    process(byte)
}

// Async directory iteration (batched, 48x faster)
for try await entry in File.Directory.Async(io: io).entries(at: directoryPath) {
    print(entry.name)
}

// Async file handle operations
let handle = try await File.Handle.Async.open(path, mode: .readWrite, io: io)
let data = try await handle.read(upToCount: 1024)
try await handle.write(contentsOf: newData)
try await handle.close()

// Graceful shutdown
await io.shutdown()
```

## Usage Examples

### Atomic Writes with Durability

```swift
// Full durability (F_FULLFSYNC on Darwin, fsync on Linux)
try File.System.Write.Atomic.write(
    data,
    to: path,
    options: .init(durability: .full)
)

// Data-only sync (faster, metadata may be stale after crash)
try File.System.Write.Atomic.write(
    data,
    to: path,
    options: .init(durability: .dataOnly)
)

// No sync (fastest, for temporary files)
try File.System.Write.Atomic.write(
    data,
    to: path,
    options: .init(durability: .none)
)
```

### File Copy Options

```swift
// Copy with attributes (permissions, timestamps)
try File.System.Copy.copy(
    from: source,
    to: destination,
    options: .init(copyAttributes: true, overwrite: true)
)

// Copy data only (uses default permissions)
try File.System.Copy.copy(
    from: source,
    to: destination,
    options: .init(copyAttributes: false)
)

// Handle symlinks
try File.System.Copy.copy(
    from: source,
    to: destination,
    options: .init(followSymlinks: false)  // Copy symlink itself
)
```

### Dedicated Thread Pool

```swift
// Use dedicated threads to avoid starving Swift's cooperative pool
let io = File.IO.Executor(.init(
    workers: 4,
    threadModel: .dedicated  // Uses DispatchQueue per worker
))

// Blocking I/O won't affect async tasks on cooperative pool
try await io.run {
    // Long-running blocking operation
    Thread.sleep(forTimeInterval: 1.0)
}

await io.shutdown()
```

### Directory Traversal with Filtering

```swift
// Walk with options
let options = File.Directory.Walk.Options(
    followSymlinks: false,
    skipHidden: true,
    maxDepth: 5
)

for entry in try File.Directory.Walk(at: rootPath, options: options) {
    if entry.type == .regular && entry.name.hasSuffix(".swift") {
        print("Found Swift file: \(entry.path)")
    }
}
```

### Streaming Bytes with Chunk Size

```swift
let io = File.IO.Executor()

// Read in 64KB chunks
let options = File.Stream.Async.BytesOptions(chunkSize: 64 * 1024)
for try await chunk in File.Stream.Async(io: io).bytes(from: path, options: options) {
    processChunk(chunk)
}
```

## Performance

### File Copy

| Operation | Time | Notes |
|-----------|------|-------|
| 100MB APFS clone | 0.2ms | Same filesystem, instant metadata copy |
| 100MB kernel copy | ~50ms | Cross-filesystem, `copyfile()` on Darwin |
| 100MB manual loop | ~150ms | 64KB buffer read/write fallback |

### Directory Iteration

| Approach | Time (1000 files) | Executor Hops |
|----------|-------------------|---------------|
| Per-entry hop | 14.81ms | 1000 |
| Batched (64) | 0.31ms | 15 |
| **Speedup** | **48x** | |

### Memory Usage

The async executor maintains bounded memory regardless of workload:
- Queue limit prevents unbounded accumulation
- Batched iteration reduces intermediate allocations
- Handle store tracks open files without leaks

### Methodology

Performance numbers are indicative, not guarantees. Measured on:
- Apple Silicon M1 (8 cores), 24 GB RAM
- macOS 26.0, Swift 6.2
- Release builds (`swift build -c release`)
- Warm filesystem cache (files read once before timing)
- APFS filesystem on internal NVMe SSD

Your results will vary based on hardware, filesystem, and workload characteristics.

## Architecture

### Layers

```
┌─────────────────────────────────────────────┐
│              File System Async              │  ← AsyncSequence, executor, handles
├─────────────────────────────────────────────┤
│             File System Primitives          │  ← Sync operations, platform abstraction
├─────────────────────────────────────────────┤
│          POSIX / Windows / Darwin           │  ← System calls
└─────────────────────────────────────────────┘
```

### Copy Fallback Ladder

| Platform | Fallback Order |
|----------|----------------|
| **Darwin** | `copyfile(CLONE_FORCE)` → `copyfile(ALL/DATA)` → manual loop |
| **Linux** | `copy_file_range` → `sendfile` → manual loop |
| **Windows** | `CopyFileW` → manual loop |

### I/O Executor

- **Cooperative mode** (default): Uses `Task.detached`, shares Swift's cooperative pool
- **Dedicated mode**: Per-worker `DispatchQueue`, isolates blocking I/O
- **Backpressure**: Bounded queue with suspension when full
- **Graceful shutdown**: Completes in-flight work, fails pending jobs

## Platform Support

### Core Filesystem Operations

| Platform | Status | Optimizations |
|----------|--------|---------------|
| macOS | Full | APFS cloning, `copyfile()`, kernel-assisted copy |
| iOS | Full | Same as macOS |
| Linux | Full | `copy_file_range`, `sendfile` |
| Windows | Partial | `CopyFileW`, some features pending |

### Async I/O

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | Full | Cooperative and dedicated thread models |
| iOS | Full | Same as macOS |
| Linux | Full | Same as macOS |
| Windows | Planned | Executor architecture ready |

### File Watching

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | Planned | FSEvents integration pending |
| iOS | Planned | FSEvents integration pending |
| Linux | Planned | inotify integration pending |
| Windows | Planned | ReadDirectoryChangesW pending |

## Non-goals

This library intentionally does not provide:

- **Virtual filesystem abstraction**: No pluggable backends or mock filesystems. Use protocol abstraction at a higher layer if needed.
- **Security sandbox**: Path validation is structural, not a security boundary. Do not use `File.Path` to prevent directory traversal attacks in untrusted input.
- **Database replacement**: For transactional semantics across multiple files, use SQLite or a proper database.
- **Watcher-first design**: File watching is planned but not the primary focus. For complex watching needs, consider dedicated solutions.
- **Complete Windows parity**: Windows support covers core operations; advanced features (ACLs, alternate data streams) are not prioritized.

## Testing

```bash
# All tests (660 tests)
swift test

# Specific test suites
swift test --filter "File.System.Copy"
swift test --filter "File.IO.Executor"
swift test --filter "EdgeCase"

# Performance tests
swift test --filter "Performance"
```

Test coverage includes:
- Copy semantics (attributes, symlinks, overwrite)
- Atomic write durability modes
- Async batching and cancellation
- Executor thread model isolation
- Edge cases (empty files, long paths, unicode)
- Cross-platform behavior

## Related Packages

### Dependencies

- [apple/swift-system](https://github.com/apple/swift-system): Low-level system types
- [apple/swift-async-algorithms](https://github.com/apple/swift-async-algorithms): Async sequence algorithms
- [swift-standards](https://github.com/swift-standards/swift-standards): Binary serialization, time types

### See Also

- [swift-nio](https://github.com/apple/swift-nio): Event-driven network framework
- [swift-log](https://github.com/apple/swift-log): Logging API

## Contributing

Contributions welcome. Please:

1. Add tests - maintain coverage for new features
2. Follow conventions - Swift 6, strict concurrency, no force-unwraps
3. Update docs - inline documentation and README updates

Areas for contribution:
- Windows feature parity
- File watching implementation (FSEvents, inotify)
- Performance optimizations
- Additional edge case coverage

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
