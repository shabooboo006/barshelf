import Foundation

enum Log {
    static func line(_ s: String) {
        let msg = "[spike] \(s)\n"
        FileHandle.standardError.write(Data(msg.utf8))
    }
}
