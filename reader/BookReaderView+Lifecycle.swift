import SwiftUI
import SwiftData

extension BookReaderView {
    @MainActor
    func parseContent(_ content: String) async {
        let parsed = await Task.detached(priority: .userInitiated) {
            let splitLines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var chapterList: [Chapter] = []
            var lineSet: Set<Int> = []
            var lineIdxList: [Int] = []

            for (idx, line) in splitLines.enumerated() {
                if await isChapter(line) {
                    chapterList.append(Chapter(
                        title: line.trimmingCharacters(in: .whitespaces),
                        lineIndex: idx
                    ))
                    lineSet.insert(idx)
                    lineIdxList.append(idx)
                }
            }
            return (splitLines, chapterList, lineSet, lineIdxList)
        }.value

        lines = parsed.0
        chapters = parsed.1
        chapterLineSet = parsed.2
        chapterLineIndices = parsed.3
        rebuildPagesIfNeeded()
    }

    func restoreInitialPositionIfNeeded() {
        guard !hasRestoredInitialPosition, !lines.isEmpty else { return }

        if pageMode == .horizontal {
            guard !pages.isEmpty else { return }
            let targetPage = min(max(0, book.currentPage), pages.count - 1)
            currentPageIdx = targetPage

            if !displayLines.isEmpty {
                let firstDLIdx = pages[targetPage].lineRange.lowerBound
                let firstLine = displayLines[min(firstDLIdx, displayLines.count - 1)].originalLineIndex
                currentChapterIdx = chapterIndex(for: firstLine)
            }
            readingProgress = Double(targetPage) / Double(max(1, pages.count - 1))
            hasRestoredInitialPosition = true
            return
        }

        let targetLine = min(max(0, book.lastReadLineIndex), max(0, lines.count - 1))
        jumpToLineIndex = targetLine
        currentChapterIdx = chapterIndex(for: targetLine)
        readingProgress = Double(targetLine) / Double(max(1, lines.count - 1))
        hasRestoredInitialPosition = true
    }

    func persistReadingPosition(force: Bool) {
        guard !lines.isEmpty else { return }

        if !force {
            let now = Date()
            if now.timeIntervalSince(lastPersistAt) < 2 {
                return
            }
            lastPersistAt = now
        } else {
            lastPersistAt = Date()
        }

        let currentLine: Int
        if pageMode == .scroll {
            currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
            book.currentPage = 0
            book.totalPages = 0
        } else if !pages.isEmpty, currentPageIdx < pages.count, !displayLines.isEmpty {
            let dlIdx = pages[currentPageIdx].lineRange.lowerBound
            currentLine = displayLines[min(dlIdx, displayLines.count - 1)].originalLineIndex
            book.currentPage = currentPageIdx
            book.totalPages = pages.count
        } else {
            currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
        }

        book.lastReadLineIndex = currentLine
        book.lastOpenDate = Date()

        if force {
            do {
                try modelContext.save()
            } catch {
                // 避免持久化失败阻断阅读流程。
            }
        }
    }

    func updateTimeAndBattery() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())

        let currentBatteryLevel = UIDevice.current.batteryLevel
        if currentBatteryLevel >= 0 {
            batteryLevel = currentBatteryLevel
        }
        batteryState = UIDevice.current.batteryState
    }
}
