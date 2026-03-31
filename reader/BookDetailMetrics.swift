import Foundation

struct BookDetailMetrics {
    let wordCount: Int
    let lineCount: Int
    let chapterCount: Int
}

enum BookDetailMetricsCalculator {
    private static let chapterRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(第[零一二三四五六七八九十百千万\d]+[章节卷集部回篇]|Chapter\s*\d+|CHAPTER\s*\d+)"#,
        options: .anchorsMatchLines
    )

    static func calculate(from content: String) async -> BookDetailMetrics {
        let wc = await Task.detached(priority: .userInitiated) {
            content.filter { !$0.isWhitespace }.count
        }.value
        let lc = await Task.detached(priority: .userInitiated) {
            content.split(separator: "\n", omittingEmptySubsequences: false).count
        }.value
        let cc = await Task.detached(priority: .userInitiated) {
            guard let regex = await chapterRegex else { return 0 }
            let range = NSRange(content.startIndex..., in: content)
            return regex.numberOfMatches(in: content, range: range)
        }.value

        return BookDetailMetrics(wordCount: wc, lineCount: lc, chapterCount: cc)
    }
}
