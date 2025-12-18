//
//  Test.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing

extension Test {
    @Suite(.serialized)
    struct `File System` {
        struct `Unit` {}

        // Phase 2: Additional themed suites
        // @Suite(.serialized, .tags(.integration))
        // struct `Integration` {}
        //
        // @Suite(.serialized, .tags(.performance))
        // struct `Performance` {}
    }
}

extension Tag {
    @Tag static var integration: Self
    @Tag static var performance: Self
}
