//
//  File.System.Metadata.Timestamps.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Metadata {
    /// File timestamp information.
    public struct Timestamps: Sendable, Equatable {
        /// Last access time (seconds since epoch).
        public var accessTime: Int64

        /// Last access time (nanoseconds component).
        public var accessTimeNanoseconds: Int64

        /// Last modification time (seconds since epoch).
        public var modificationTime: Int64

        /// Last modification time (nanoseconds component).
        public var modificationTimeNanoseconds: Int64

        /// Status change time (seconds since epoch).
        public var changeTime: Int64

        /// Status change time (nanoseconds component).
        public var changeTimeNanoseconds: Int64

        /// Creation time (seconds since epoch), if available.
        public var creationTime: Int64?

        /// Creation time (nanoseconds component), if available.
        public var creationTimeNanoseconds: Int64?

        public init(
            accessTime: Int64,
            accessTimeNanoseconds: Int64 = 0,
            modificationTime: Int64,
            modificationTimeNanoseconds: Int64 = 0,
            changeTime: Int64,
            changeTimeNanoseconds: Int64 = 0,
            creationTime: Int64? = nil,
            creationTimeNanoseconds: Int64? = nil
        ) {
            self.accessTime = accessTime
            self.accessTimeNanoseconds = accessTimeNanoseconds
            self.modificationTime = modificationTime
            self.modificationTimeNanoseconds = modificationTimeNanoseconds
            self.changeTime = changeTime
            self.changeTimeNanoseconds = changeTimeNanoseconds
            self.creationTime = creationTime
            self.creationTimeNanoseconds = creationTimeNanoseconds
        }
    }
}
