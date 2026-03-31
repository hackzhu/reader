import SwiftUI

extension BookReaderView {
    @ViewBuilder
    var searchOverlayView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSearch = false
                        searchText = ""
                        searchResults = []
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.textColor)
                        .padding(.leading, 6)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textColor.opacity(0.4))
                    TextField("搜索全书内容…", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textColor)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { performSearch() }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textColor.opacity(0.35))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.textColor.opacity(0.06))
                .cornerRadius(10)

                Button {
                    performSearch()
                } label: {
                    Text("搜索")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.orange)
                }
                .padding(.trailing, 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(theme.background)

            Divider().background(theme.textColor.opacity(0.12))

            if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(theme.textColor.opacity(0.3))
                    Text("未找到相关内容")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textColor.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else if searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(theme.textColor.opacity(0.2))
                    Text("输入关键字搜索全书")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textColor.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else {
                HStack {
                    Text("共找到 \(searchResults.count) 处")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textColor.opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.background)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(searchResults) { result in
                            searchResultCard(result)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(theme.background)
            }
        }
        .background(theme.background.ignoresSafeArea())
    }

    @ViewBuilder
    func searchResultCard(_ result: SearchResult) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showSearch = false
                searchText = ""
                searchResults = []
            }
            jumpToLineIndex = result.lineIndex
            currentChapterIdx = chapterIndex(for: result.lineIndex)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.orange)
                    Text(result.chapterName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.orange)
                    Spacer()
                }

                highlightedText(result.lineText, keyword: result.keyword)
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.textColor.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.textColor.opacity(0.08), lineWidth: 1)
            )
        }
    }

    func highlightedText(_ text: String, keyword: String) -> Text {
        guard !keyword.isEmpty else {
            return Text(text).foregroundColor(theme.textColor.opacity(0.8))
        }

        let lowText = text.lowercased()
        let lowKey = keyword.lowercased()
        var attributed = AttributedString()
        var searchStart = lowText.startIndex

        while let range = lowText.range(of: lowKey, range: searchStart..<lowText.endIndex) {
            var before = AttributedString(text[searchStart..<range.lowerBound])
            before.foregroundColor = theme.textColor.opacity(0.75)
            attributed.append(before)

            var matched = AttributedString(text[range.lowerBound..<range.upperBound])
            matched.foregroundColor = Color.orange
            matched.font = .boldSystemFont(ofSize: 14)
            attributed.append(matched)

            searchStart = range.upperBound
        }

        if searchStart < lowText.endIndex {
            var tail = AttributedString(text[searchStart..<text.endIndex])
            tail.foregroundColor = theme.textColor.opacity(0.75)
            attributed.append(tail)
        }
        return Text(attributed)
    }

    func performSearch() {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            searchTask?.cancel()
            searchResults = []
            return
        }

        searchTask?.cancel()
        let snapshotLines = lines
        let snapshotChapters = chapters
        let snapshotChapterLineIndices = chapterLineIndices

        searchTask = Task.detached(priority: .userInitiated) {
            let lowKeyword = keyword.lowercased()
            var results: [SearchResult] = []
            results.reserveCapacity(64)

            func chapterIndexLocal(for lineIdx: Int) -> Int {
                guard !snapshotChapterLineIndices.isEmpty else { return 0 }
                var lo = 0
                var hi = snapshotChapterLineIndices.count - 1
                while lo < hi {
                    let mid = (lo + hi + 1) / 2
                    if snapshotChapterLineIndices[mid] <= lineIdx {
                        lo = mid
                    } else {
                        hi = mid - 1
                    }
                }
                return lo
            }

            for (index, line) in snapshotLines.enumerated() {
                if Task.isCancelled { return }
                if line.lowercased().contains(lowKeyword) {
                    let chapIdx = chapterIndexLocal(for: index)
                    let chapName: String
                    if snapshotChapters.isEmpty {
                        chapName = "第\(index + 1)行"
                    } else if chapIdx < snapshotChapters.count {
                        chapName = snapshotChapters[chapIdx].title
                    } else {
                        chapName = "未知章节"
                    }
                    results.append(SearchResult(
                        lineIndex: index,
                        lineText: line.trimmingCharacters(in: .whitespaces),
                        chapterName: chapName,
                        keyword: keyword
                    ))
                }
            }

            let finalResults = results
            await MainActor.run {
                searchResults = finalResults
            }
        }
    }
}
