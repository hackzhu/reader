import SwiftUI

extension BookReaderView {
    func rebuildPagesIfNeeded() {
        guard pageMode != .scroll else {
            paginationTask?.cancel()
            pendingModeSwitchLineIndex = nil
            pages = []
            displayLines = []
            return
        }
        guard !lines.isEmpty else {
            paginationTask?.cancel()
            pages = []
            displayLines = []
            return
        }

        let vpHeight = pageViewportSize.height
        guard vpHeight > 100 else {
            paginationTask?.cancel()
            pages = []
            displayLines = []
            return
        }

        paginationTask?.cancel()
        let token = UUID()
        paginationToken = token

        let snapshotLines = lines
        let snapshotChapterSet = chapterLineSet
        let snapshotTextSize = textSize
        let snapshotLineSpacing = lineSpacing
        let snapshotWrapLineSpacing = wrapLineSpacing
        let snapshotViewportSize = pageViewportSize
        let snapshotReadingProgress = readingProgress
        let snapshotOldPageIdx = currentPageIdx
        let snapshotPendingModeSwitchLine = pendingModeSwitchLineIndex
        let snapshotOldPages = pages
        let snapshotOldDisplayLines = displayLines

        let snapshotAnchorLineIndex: Int = {
            if let targetLine = snapshotPendingModeSwitchLine {
                return targetLine
            }
            if !snapshotOldPages.isEmpty,
               snapshotOldPageIdx < snapshotOldPages.count,
               !snapshotOldDisplayLines.isEmpty {
                let dlIdx = snapshotOldPages[snapshotOldPageIdx].lineRange.lowerBound
                return snapshotOldDisplayLines[min(dlIdx, snapshotOldDisplayLines.count - 1)].originalLineIndex
            }
            return Int(snapshotReadingProgress * Double(max(1, snapshotLines.count - 1)))
        }()

        paginationTask = Task.detached(priority: .userInitiated) {
            let usableHeight = snapshotViewportSize.height
            let usableWidth = max(1, snapshotViewportSize.width - 40)
            let fontLineH = snapshotTextSize * 1.2
            let chapterFontLineH = (snapshotTextSize + 3) * 1.2
            let avgCharWidth: CGFloat = snapshotTextSize
            let charsPerVisualLine = max(1, Int(usableWidth / avgCharWidth))
            let avgChapterCharWidth: CGFloat = snapshotTextSize + 3
            let charsPerChapterLine = max(1, Int(usableWidth / avgChapterCharWidth))

            var dLines: [DisplayLine] = []
            dLines.reserveCapacity(snapshotLines.count)

            for i in 0..<snapshotLines.count {
                if Task.isCancelled { return }
                let isChap = snapshotChapterSet.contains(i)
                let text = snapshotLines[i]

                if isChap {
                    dLines.append(DisplayLine(text: text, isChapter: true, originalLineIndex: i, isFirstOfParagraph: true, isLastOfParagraph: true))
                } else {
                    let charCount = text.count
                    if charCount <= charsPerVisualLine {
                        dLines.append(DisplayLine(text: text, isChapter: false, originalLineIndex: i, isFirstOfParagraph: true, isLastOfParagraph: true))
                    } else {
                        var startIdx = text.startIndex
                        var segIndex = 0
                        while startIdx < text.endIndex {
                            let endIdx = text.index(startIdx, offsetBy: charsPerVisualLine, limitedBy: text.endIndex) ?? text.endIndex
                            let seg = String(text[startIdx..<endIdx])
                            dLines.append(DisplayLine(text: seg, isChapter: false, originalLineIndex: i, isFirstOfParagraph: segIndex == 0, isLastOfParagraph: false))
                            startIdx = endIdx
                            segIndex += 1
                        }
                        if segIndex > 1 {
                            let last = dLines.count - 1
                            let v = dLines[last]
                            dLines[last] = DisplayLine(text: v.text, isChapter: v.isChapter, originalLineIndex: v.originalLineIndex, isFirstOfParagraph: v.isFirstOfParagraph, isLastOfParagraph: true)
                        }
                    }
                }
            }

            let soloLineH = fontLineH + snapshotLineSpacing
            let firstLineH = fontLineH + snapshotLineSpacing / 2 + snapshotWrapLineSpacing / 2
            let middleLineH = fontLineH + snapshotWrapLineSpacing
            let lastLineH = fontLineH + snapshotWrapLineSpacing / 2 + snapshotLineSpacing / 2

            var result: [PageData] = []
            var pageStart = 0
            var accHeight: CGFloat = 0
            var pageId = 0

            for i in 0..<dLines.count {
                if Task.isCancelled { return }
                let dl = dLines[i]
                let effectiveH: CGFloat
                if dl.isChapter {
                    let charCount = dl.text.trimmingCharacters(in: .whitespaces).count
                    let visualLines = max(1, Int(ceil(Double(charCount) / Double(charsPerChapterLine))))
                    effectiveH = CGFloat(visualLines) * chapterFontLineH + 49
                } else if dl.isFirstOfParagraph && dl.isLastOfParagraph {
                    effectiveH = soloLineH
                } else if dl.isFirstOfParagraph {
                    effectiveH = firstLineH
                } else if dl.isLastOfParagraph {
                    effectiveH = lastLineH
                } else {
                    effectiveH = middleLineH
                }

                if dl.isChapter && i > pageStart {
                    result.append(PageData(id: pageId, lineRange: pageStart..<i))
                    pageId += 1
                    pageStart = i
                    accHeight = effectiveH
                } else if accHeight + effectiveH > usableHeight && i > pageStart {
                    result.append(PageData(id: pageId, lineRange: pageStart..<i))
                    pageId += 1
                    pageStart = i
                    accHeight = effectiveH
                } else {
                    accHeight += effectiveH
                }
            }
            if pageStart < dLines.count {
                result.append(PageData(id: pageId, lineRange: pageStart..<dLines.count))
            }

            let resolvedPage: Int = {
                guard !result.isEmpty else { return 0 }
                if let dlIdx = dLines.firstIndex(where: { $0.originalLineIndex >= snapshotAnchorLineIndex }),
                   let newPageIdx = result.firstIndex(where: { $0.lineRange.contains(dlIdx) }) {
                    return newPageIdx
                }
                return min(snapshotOldPageIdx, result.count - 1)
            }()

            let finalDisplayLines = dLines
            let finalPages = result

            await MainActor.run {
                guard paginationToken == token else { return }
                displayLines = finalDisplayLines
                pages = finalPages
                if !finalPages.isEmpty {
                    if let targetLine = snapshotPendingModeSwitchLine,
                       let dlIdx = finalDisplayLines.firstIndex(where: { $0.originalLineIndex >= targetLine }),
                       let pageIdx = finalPages.firstIndex(where: { $0.lineRange.contains(dlIdx) }) {
                        currentPageIdx = pageIdx
                        readingProgress = Double(pageIdx) / Double(max(1, finalPages.count - 1))
                    } else {
                        currentPageIdx = resolvedPage
                    }
                }
                pendingModeSwitchLineIndex = nil
                restoreInitialPositionIfNeeded()
            }
        }
    }
}
