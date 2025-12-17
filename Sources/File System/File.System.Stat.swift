//
//  File.System.Stat.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for file status and existence checks.
    public enum Stat {}
}

extension File.System.Stat {
    /// Error type for stat operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case statFailed(errno: Int32, message: String)
    }
}
