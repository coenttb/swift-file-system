//
//  Test.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing
import File_System_Primitives

extension Test {
    struct Unit {}
    struct EdgeCase {}
    @Suite(.serialized)
    struct Performance {}
}

extension File.System {
    typealias Test = Testing.Test
}
