// Usage: swift run scl2html Examples/ji-5-limit.scl > out.html && open out.html
import Foundation
import SclCore

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: scl2html file.scl > out.html\n".utf8))
    exit(2)
}
do {
    let url = URL(fileURLWithPath: args[1])
    let data = try Data(contentsOf: url)
    print(Scl.html(from: data, fileName: url.lastPathComponent))
} catch {
    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
