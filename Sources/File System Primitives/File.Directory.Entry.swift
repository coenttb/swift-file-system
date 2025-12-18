//
//  File.Directory.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Directory {
    /// A directory entry representing a file or subdirectory.
    public struct Entry: Sendable {
        /// The name of the entry.
        public let name: String

        /// The full path to the entry.
        public let path: File.Path

        /// The type of the entry.
        public let type: EntryType

        public init(name: String, path: File.Path, type: EntryType) {
            self.name = name
            self.path = path
            self.type = type
        }
    }

    /// The type of a directory entry.
    public enum EntryType: Sendable {
        case file
        case directory
        case symbolicLink
        case other
    }
}
