import SwiftUI
import SwiftData
import UIKit

struct BookReaderView: View {
    @Bindable var book: Book

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase

    // 阅读设置
    @AppStorage("textSize") var textSize: Double = 18
    @AppStorage("lineSpacing") var lineSpacing: Double = 12
    @AppStorage("wrapLineSpacing") var wrapLineSpacing: Double = 6
    @State var theme: ReadingTheme = .white
    @AppStorage("pageMode") var pageMode: PageMode = .horizontal
    @AppStorage("fontFamily") var fontFamilyRawValue: String = ReadingFontFamily.system.rawValue
    @AppStorage("keepScreenOn") var keepScreenOn: Bool = false

    // UI 状态
    @State var showBars: Bool = false
    @State var showTOC: Bool = false
    @State var showSettings: Bool = false
    @State var showSearch: Bool = false
    @State var showBookDetail: Bool = false
    @State var jumpToLineIndex: Int? = nil

    // 搜索状态
    @State var searchText: String = ""
    @State var searchResults: [SearchResult] = []

    // 顶部状态栏
    @State var currentTime: String = ""
    @State var batteryLevel: Float = -1
    @State var batteryState: UIDevice.BatteryState = .unknown

    // 进度 & 章节追踪
    @State var readingProgress: Double = 0
    @State var isDraggingSlider: Bool = false
    @State var currentChapterIdx: Int = 0
    @State var contentHeight: CGFloat = 0
    @State var viewportHeight: CGFloat = 0
    @State var viewportWidth: CGFloat = 0

    // 翻页模式状态
    @State var pages: [PageData] = []
    @State var currentPageIdx: Int = 0
    @State var pageViewportSize: CGSize = .zero
    @State var displayLines: [DisplayLine] = []
    @State var hasRestoredInitialPosition: Bool = false
    @State var lastPersistAt: Date = .distantPast
    @State var paginationTask: Task<Void, Never>? = nil
    @State var paginationToken: UUID = UUID()
    @State var searchTask: Task<Void, Never>? = nil
    @State var pendingModeSwitchLineIndex: Int? = nil

    // 内容预处理缓存
    @State var lines: [String] = []
    @State var chapters: [Chapter] = []
    @State var chapterLineSet: Set<Int> = []
    @State var chapterLineIndices: [Int] = []

    var barsActive: Bool { showBars || showSearch || showTOC }

    var prevChapter: Chapter? {
        guard !chapters.isEmpty, currentChapterIdx > 0 else { return nil }
        return chapters[currentChapterIdx - 1]
    }

    var nextChapter: Chapter? {
        guard !chapters.isEmpty, currentChapterIdx < chapters.count - 1 else { return nil }
        return chapters[currentChapterIdx + 1]
    }

    var chapterPageLabel: String {
        guard !chapters.isEmpty, currentChapterIdx < chapters.count else { return "" }
        let chapStart = chapters[currentChapterIdx].lineIndex
        let chapEnd: Int
        if currentChapterIdx + 1 < chapters.count {
            chapEnd = chapters[currentChapterIdx + 1].lineIndex
        } else {
            chapEnd = lines.count
        }
        guard chapEnd > chapStart else { return "" }

        if pageMode == .scroll {
            let currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
            let chapLines = chapEnd - chapStart
            let linesPerPage = max(1, Int(max(1, viewportHeight - 32) / (textSize * 1.2 + lineSpacing)))
            let totalPagesInChap = max(1, (chapLines + linesPerPage - 1) / linesPerPage)
            let lineInChap = max(0, min(currentLine - chapStart, chapLines - 1))
            let curPage = min(lineInChap / linesPerPage + 1, totalPagesInChap)
            return "\(curPage)/\(totalPagesInChap)"
        }

        guard !pages.isEmpty, !displayLines.isEmpty else { return "" }
        let chapterPages = pages.filter { page in
            guard page.lineRange.lowerBound < displayLines.count else { return false }
            let firstOrig = displayLines[page.lineRange.lowerBound].originalLineIndex
            return firstOrig >= chapStart && firstOrig < chapEnd
        }
        guard !chapterPages.isEmpty else { return "" }
        let totalPagesInChap = chapterPages.count
        if let posInChap = chapterPages.firstIndex(where: { $0.id == currentPageIdx }) {
            return "\(posInChap + 1)/\(totalPagesInChap)"
        }
        return "1/\(totalPagesInChap)"
    }

    var batteryIconName: String {
        if batteryLevel < 0 { return "battery.100" }
        let isCharging = batteryState == .charging || batteryState == .full
        if isCharging { return "battery.100.bolt" }
        if batteryLevel > 0.75 { return "battery.100" }
        if batteryLevel > 0.50 { return "battery.75" }
        if batteryLevel > 0.25 { return "battery.50" }
        if batteryLevel > 0.10 { return "battery.25" }
        return "battery.0"
    }

    var batteryLevelText: String {
        guard batteryLevel >= 0 else { return "--%" }
        return "\(Int(batteryLevel * 100))%"
    }

    var batteryTintColor: Color {
        if batteryLevel >= 0 && batteryLevel <= 0.2 {
            return Color.red.opacity(0.5)
        }
        return theme.textColor.opacity(0.3)
    }

    var fontFamily: ReadingFontFamily {
        get { ReadingFontFamily(rawValue: fontFamilyRawValue) ?? .system }
        set { fontFamilyRawValue = newValue.rawValue }
    }

    func bodyFont(size: CGFloat) -> Font {
        if let name = fontFamily.postScriptName {
            return .custom(name, size: size)
        }
        return .system(size: size)
    }

    func chapterFont(size: CGFloat) -> Font {
        if let name = fontFamily.postScriptName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .bold)
    }

    func chapterIndex(for lineIdx: Int) -> Int {
        guard !chapterLineIndices.isEmpty else { return 0 }
        var lo = 0
        var hi = chapterLineIndices.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if chapterLineIndices[mid] <= lineIdx {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
    }

    func currentReadingLineIndex(for mode: PageMode) -> Int {
        guard !lines.isEmpty else { return 0 }
        if mode == .scroll {
            return Int(readingProgress * Double(max(1, lines.count - 1)))
        }
        if !pages.isEmpty, currentPageIdx < pages.count, !displayLines.isEmpty {
            let dlIdx = pages[currentPageIdx].lineRange.lowerBound
            return displayLines[min(dlIdx, displayLines.count - 1)].originalLineIndex
        }
        return Int(readingProgress * Double(max(1, lines.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topStatusBar
                    .opacity(barsActive ? 0 : 1)
                    .allowsHitTesting(!barsActive)

                switch pageMode {
                case .scroll:
                    scrollReadingView
                case .horizontal:
                    horizontalPagedView
                }

                bottomStatusBar
                    .opacity(barsActive ? 0 : 1)
                    .allowsHitTesting(!barsActive)
            }

            if showTOC {
                tocOverlay
            }

            if showSearch {
                searchOverlayView
                    .transition(.opacity)
                    .zIndex(12)
            }

            if showBars {
                barsOverlay
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showBars)
        .preferredColorScheme(theme == .night ? .dark : .light)
        .onAppear {
            book.lastOpenDate = Date()
            UIDevice.current.isBatteryMonitoringEnabled = true
            UIApplication.shared.isIdleTimerDisabled = keepScreenOn
            restoreInitialPositionIfNeeded()
            persistReadingPosition(force: true)
        }
        .onDisappear {
            paginationTask?.cancel()
            searchTask?.cancel()
            persistReadingPosition(force: true)
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: keepScreenOn) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                persistReadingPosition(force: true)
            }
        }
        .sheet(isPresented: $showBookDetail) {
            NavigationStack {
                BookDetailView(book: book)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") { showBookDetail = false }
                        }
                    }
            }
        }
        .task(id: book.content) {
            hasRestoredInitialPosition = false
            await parseContent(book.content)
            restoreInitialPositionIfNeeded()
        }
        .task {
            while !Task.isCancelled {
                updateTimeAndBattery()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: textSize) { _, _ in rebuildPagesIfNeeded() }
        .onChange(of: lineSpacing) { _, _ in rebuildPagesIfNeeded() }
        .onChange(of: wrapLineSpacing) { _, _ in rebuildPagesIfNeeded() }
        .onChange(of: pageMode) { oldMode, newMode in
            let targetLine = currentReadingLineIndex(for: oldMode)
            pendingModeSwitchLineIndex = targetLine
            currentChapterIdx = chapterIndex(for: targetLine)
            readingProgress = Double(targetLine) / Double(max(1, lines.count - 1))
            if newMode == .scroll {
                jumpToLineIndex = targetLine
            }
            rebuildPagesIfNeeded()
            persistReadingPosition(force: true)
        }
        .onChange(of: pageViewportSize) { _, _ in rebuildPagesIfNeeded() }
    }

    @ViewBuilder
    var tocOverlay: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { showTOC = false }
                    }

                TOCDrawerView(
                    chapters: chapters,
                    currentChapterIndex: currentChapterIdx,
                    theme: theme,
                    onSelect: { chapter in
                        withAnimation(.easeInOut(duration: 0.25)) { showTOC = false }
                        jumpToLineIndex = chapter.lineIndex
                        currentChapterIdx = chapterIndex(for: chapter.lineIndex)
                    }
                )
                .frame(width: geo.size.width * 0.72)
                .shadow(color: Color.black.opacity(0.25), radius: 20, x: 6, y: 0)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .zIndex(10)
    }
}
