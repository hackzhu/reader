import Foundation

private let chapterRegex: NSRegularExpression? = {
    let pattern = #"^[\s　]*((第\s*[零一二三四五六七八九十百千万\d]+\s*[章回节集卷部篇])|([A-Z][a-z]*\s+\d+)|(Chapter\s+\d+)|(CHAPTER\s+\d+)|(序章|终章|尾声|楔子|引子|后记|番外|外传))[^\n]*$"#
    return try? NSRegularExpression(pattern: pattern, options: [])
}()

func isChapter(_ line: String) -> Bool {
    guard let regex = chapterRegex else { return false }
    let range = NSRange(line.startIndex..., in: line)
    return regex.firstMatch(in: line, options: [], range: range) != nil
}
