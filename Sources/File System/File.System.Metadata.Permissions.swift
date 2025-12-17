//
//  File.System.Metadata.Permissions.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Metadata {
    /// POSIX file permissions.
    public struct Permissions: OptionSet, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        // Owner permissions
        public static let ownerRead = Permissions(rawValue: 0o400)
        public static let ownerWrite = Permissions(rawValue: 0o200)
        public static let ownerExecute = Permissions(rawValue: 0o100)

        // Group permissions
        public static let groupRead = Permissions(rawValue: 0o040)
        public static let groupWrite = Permissions(rawValue: 0o020)
        public static let groupExecute = Permissions(rawValue: 0o010)

        // Other permissions
        public static let otherRead = Permissions(rawValue: 0o004)
        public static let otherWrite = Permissions(rawValue: 0o002)
        public static let otherExecute = Permissions(rawValue: 0o001)

        // Special bits
        public static let setuid = Permissions(rawValue: 0o4000)
        public static let setgid = Permissions(rawValue: 0o2000)
        public static let sticky = Permissions(rawValue: 0o1000)

        // Common combinations
        public static let ownerAll: Permissions = [.ownerRead, .ownerWrite, .ownerExecute]
        public static let groupAll: Permissions = [.groupRead, .groupWrite, .groupExecute]
        public static let otherAll: Permissions = [.otherRead, .otherWrite, .otherExecute]

        /// Default file permissions (644).
        public static let defaultFile: Permissions = [.ownerRead, .ownerWrite, .groupRead, .otherRead]

        /// Default directory permissions (755).
        public static let defaultDirectory: Permissions = [.ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute]

        /// Executable file permissions (755).
        public static let executable: Permissions = [.ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute]
    }
}
