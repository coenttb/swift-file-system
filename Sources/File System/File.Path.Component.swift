//
//  File.Path.Component.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import SystemPackage

extension File.Path {
    /// A single component of a file path.
    ///
    /// A component represents a single directory or file name within a path.
    /// For example, in `/usr/local/bin`, the components are `usr`, `local`, and `bin`.
    public struct Component: Hashable, Sendable {
        @usableFromInline
        internal var _component: FilePath.Component

        /// Creates a component from a SystemPackage FilePath.Component.
        @inlinable
        internal init(_ component: FilePath.Component) {
            self._component = component
        }

        /// Creates a component from a string.
        @inlinable
        public init(_ string: String) {
            self._component = FilePath.Component(string)!
        }
    }
}

// MARK: - Properties

extension File.Path.Component {
    /// The string representation of this component.
    @inlinable
    public var string: String {
        _component.string
    }

    /// The file extension, or `nil` if there is none.
    @inlinable
    public var `extension`: String? {
        _component.extension
    }

    /// The filename without extension.
    @inlinable
    public var stem: String? {
        _component.stem
    }

    /// The underlying SystemPackage FilePath.Component.
    @inlinable
    public var filePathComponent: FilePath.Component {
        _component
    }
}

// MARK: - CustomStringConvertible

extension File.Path.Component: CustomStringConvertible {
    @inlinable
    public var description: String {
        string
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Path.Component: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Path.Component(\(string.debugDescription))"
    }
}

// MARK: - ExpressibleByStringLiteral

extension File.Path.Component: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
