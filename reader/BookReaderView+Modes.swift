import SwiftUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension BookReaderView {
    @ViewBuilder
    var scrollReadingView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        lineView(index: index, line: line)
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(
                    GeometryReader { inner in
                        Color.clear
                            .preference(key: ScrollContentHeightKey.self, value: inner.size.height)
                            .preference(key: ScrollOffsetKey.self, value: inner.frame(in: .named("scroll")).minY)
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        viewportHeight = geo.size.height
                        viewportWidth = geo.size.width
                    }
                }
            )
            .onPreferenceChange(ScrollContentHeightKey.self) { h in
                contentHeight = h
            }
            .onPreferenceChange(ScrollOffsetKey.self) { offsetY in
                guard !isDraggingSlider, !lines.isEmpty else { return }
                let scrolled = max(0, -offsetY)
                let scrollable = max(1, contentHeight - viewportHeight)
                let newProgress = min(1.0, scrolled / scrollable)
                if abs(newProgress - readingProgress) > 0.003 {
                    readingProgress = newProgress
                    let line = Int(newProgress * Double(max(1, lines.count - 1)))
                    currentChapterIdx = chapterIndex(for: line)
                    persistReadingPosition(force: false)
                }
            }
            .onChange(of: jumpToLineIndex) { _, newIdx in
                guard let idx = newIdx else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(idx, anchor: .top)
                }
                jumpToLineIndex = nil
                let total = max(1, lines.count - 1)
                readingProgress = Double(idx) / Double(total)
                currentChapterIdx = chapterIndex(for: idx)
                persistReadingPosition(force: true)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                handleTapZone(at: value.location, viewWidth: viewportWidth)
            }
        )
    }

    @ViewBuilder
    var horizontalPagedView: some View {
        GeometryReader { geo in
            TabView(selection: $currentPageIdx) {
                ForEach(pages) { page in
                    pageContentView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onAppear {
                pageViewportSize = geo.size
            }
            .onChange(of: geo.size) { _, newSize in
                pageViewportSize = newSize
            }
            .onChange(of: currentPageIdx) { _, newPage in
                guard !pages.isEmpty, !displayLines.isEmpty else { return }
                let totalPages = max(1, pages.count - 1)
                readingProgress = Double(newPage) / Double(totalPages)
                let firstDLIdx = pages[min(newPage, pages.count - 1)].lineRange.lowerBound
                let firstLine = displayLines[min(firstDLIdx, displayLines.count - 1)].originalLineIndex
                currentChapterIdx = chapterIndex(for: firstLine)
                persistReadingPosition(force: false)
            }
            .onChange(of: jumpToLineIndex) { _, newIdx in
                guard let idx = newIdx else { return }
                if let dlIdx = displayLines.firstIndex(where: { $0.originalLineIndex >= idx }),
                   let pageIdx = pages.firstIndex(where: { $0.lineRange.contains(dlIdx) }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPageIdx = pageIdx
                    }
                }
                jumpToLineIndex = nil
                let totalPages = max(1, pages.count - 1)
                readingProgress = Double(currentPageIdx) / Double(totalPages)
                currentChapterIdx = chapterIndex(for: idx)
                persistReadingPosition(force: true)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                handleTapZone(at: value.location, viewWidth: pageViewportSize.width)
            }
        )
    }

    func handleTapZone(at location: CGPoint, viewWidth: CGFloat) {
        guard viewWidth > 0 else { return }
        if showBars {
            withAnimation(.easeInOut(duration: 0.2)) {
                showBars = false
                showSettings = false
            }
            return
        }

        let leftThreshold = viewWidth / 3
        let rightThreshold = viewWidth * 2 / 3

        if location.x < leftThreshold {
            tapPreviousPage()
        } else if location.x > rightThreshold {
            tapNextPage()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showBars = true
            }
        }
    }

    func tapPreviousPage() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch pageMode {
        case .scroll:
            let linesPerPage = max(1, Int(viewportHeight / (textSize * 1.2 + lineSpacing)))
            let scrollLines = max(1, linesPerPage * 3 / 4)
            let currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
            let target = max(0, currentLine - scrollLines)
            jumpToLineIndex = target
            currentChapterIdx = chapterIndex(for: target)
        case .horizontal:
            guard !pages.isEmpty, currentPageIdx > 0 else { return }
            let newPage = currentPageIdx - 1
            withAnimation(.easeInOut(duration: 0.3)) { currentPageIdx = newPage }
        }
    }

    func tapNextPage() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch pageMode {
        case .scroll:
            let linesPerPage = max(1, Int(viewportHeight / (textSize * 1.2 + lineSpacing)))
            let scrollLines = max(1, linesPerPage * 3 / 4)
            let currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
            let target = min(lines.count - 1, currentLine + scrollLines)
            jumpToLineIndex = target
            currentChapterIdx = chapterIndex(for: target)
        case .horizontal:
            guard !pages.isEmpty, currentPageIdx < pages.count - 1 else { return }
            let newPage = currentPageIdx + 1
            withAnimation(.easeInOut(duration: 0.3)) { currentPageIdx = newPage }
        }
    }

    @ViewBuilder
    func pageContentView(page: PageData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(page.lineRange, id: \.self) { index in
                if index < displayLines.count {
                    displayLineView(displayLines[index])
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }
}
