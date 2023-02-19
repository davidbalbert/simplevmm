//
//  UART.swift
//  simplevmm
//
//  Created by David Albert on 2/19/23.
//

import Foundation

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        try! write(contentsOf: Data(string.utf8))
    }
}

// A simplified UART. For now, it only receives, no sending.
struct UART {
    var outputStream: TextOutputStream

    init(outputStream: TextOutputStream) {
        self.outputStream = outputStream
    }

    var rx: UInt8 = 0
    var tx: UInt8 = 0 {
        didSet {
            UnicodeScalar(tx).write(to: &outputStream)
        }
    }

    subscript(index: Int) -> UInt8 {
        get {
            rx
        }
        set {
            tx = newValue
        }
    }

}
