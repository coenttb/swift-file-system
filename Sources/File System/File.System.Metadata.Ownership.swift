//
//  File.System.Metadata.Ownership.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Metadata {
    /// File ownership information.
    public struct Ownership: Sendable, Equatable {
        /// User ID of the owner.
        public var uid: UInt32

        /// Group ID of the owner.
        public var gid: UInt32

        public init(uid: UInt32, gid: UInt32) {
            self.uid = uid
            self.gid = gid
        }
    }
}
