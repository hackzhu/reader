//
//  BookReaderView.swift
//  neader
//
//  Created by Jim Li on 23/3/2026.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - 阅读主题
enum ReadingTheme: String, CaseIterable, Identifiable {
    case white  = "白天"
    case eye    = "护眼"
    case wheat  = "暖黄"
    case night  = "夜间"

    var id: String { rawValue }

    var background: Color {
        switch self {
        case .white:  return Color(red: 0.98, green: 0.97, blue: 0.95)
        case .eye:    return Color(red: 0.84, green: 0.92, blue: 0.82)
        case .wheat:  return Color(red: 0.96, green: 0.91, blue: 0.78)
        case .night:  return Color(red: 0.11, green: 0.11, blue: 0.13)
        }
    }

    var textColor: Color {
        switch self {
        case .white:  return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .eye:    return Color(red: 0.17, green: 0.26, blue: 0.17)
        case .wheat:  return Color(red: 0.28, green: 0.20, blue: 0.10)
        case .night:  return Color(red: 0.78, green: 0.78, blue: 0.80)
        }
    }

    var chapterColor: Color {
        switch self {
        case .white:  return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .eye:    return Color(red: 0.10, green: 0.22, blue: 0.10)
        case .wheat:  return Color(red: 0.22, green: 0.14, blue: 0.04)
        case .night:  return Color(red: 0.95, green: 0.95, blue: 0.96)
        }
    }

    var barBackground: Color {
        switch self {
        case .white:  return Color(red: 0.14, green: 0.14, blue: 0.14)
        case .eye:    return Color(red: 0.10, green: 0.18, blue: 0.10)
        case .wheat:  return Color(red: 0.24, green: 0.16, blue: 0.06)
        case .night:  return Color(red: 0.07, green: 0.07, blue: 0.09)
        }
    }

    var icon: String {
        switch self {
        case .white:  return "sun.max"
        case .eye:    return "leaf"
        case .wheat:  return "cup.and.saucer"
        case .night:  return "moon.stars"
        }
    }
}

// MARK: - 章节模型
struct Chapter: Identifiable {
    let id = UUID()
    let title: String
    let lineIndex: Int
}

// MARK: - 翻页模式
enum PageMode: String, CaseIterable, Identifiable {
    case scroll     = "滚动"
    case horizontal = "左右"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scroll:     return "scroll"
        case .horizontal: return "arrow.left.and.right"
        }
    }
}

// MARK: - 页面模型（翻页模式用）
struct PageData: Identifiable, Equatable {
    let id: Int          // 页码索引
    let lineRange: Range<Int>  // 此页包含的行范围

    static func == (lhs: PageData, rhs: PageData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 显示行模型（翻页分页用，将长行拆为视觉行）
private struct DisplayLine {
    let text: String
    let isChapter: Bool
    let originalLineIndex: Int   // 对应 lines[] 中的索引
    let isFirstOfParagraph: Bool // 是否为该逻辑段落的第一条显示行
    let isLastOfParagraph: Bool  // 是否为该逻辑段落的最后一条显示行
}

// MARK: - 搜索结果模型
struct SearchResult: Identifiable {
    let id = UUID()
    let lineIndex: Int
    let lineText: String
    let chapterName: String
    let keyword: String        // 用于高亮
}

// MARK: - 章节正则（全局单例）
private let chapterRegex: NSRegularExpression? = {
    let pattern = #"^[\s　]*((第\s*[零一二三四五六七八九十百千万\d]+\s*[章回节集卷部篇])|([A-Z][a-z]*\s+\d+)|(Chapter\s+\d+)|(CHAPTER\s+\d+)|(序章|终章|尾声|楔子|引子|后记|番外|外传))[^\n]*$"#
    return try? NSRegularExpression(pattern: pattern, options: [])
}()

private func isChapter(_ line: String) -> Bool {
    guard let regex = chapterRegex else { return false }
    let range = NSRange(line.startIndex..., in: line)
    return regex.firstMatch(in: line, options: [], range: range) != nil
}

// MARK: - 可见行追踪（PreferenceKey）
/// 只上报 LazyVStack 整体的 minY（相对于 ScrollView 视口），
/// 结合 contentHeight 即可按比例推算当前阅读位置，
/// 彻底替代"每行都上报 Anchor"的方案，大幅减少 Preference 合并开销。
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
// MARK: - 目录侧边抽屉
struct TOCDrawerView: View {
    let chapters: [Chapter]
    let currentChapterIndex: Int?
    let theme: ReadingTheme
    let onSelect: (Chapter) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("目录")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.chapterColor)
                Spacer()
                if !chapters.isEmpty {
                    Text("\(chapters.count) 章")
                        .font(.caption)
                        .foregroundColor(theme.textColor.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider().background(theme.textColor.opacity(0.15))

            if chapters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 36))
                        .foregroundColor(theme.textColor.opacity(0.3))
                    Text("未检测到章节标题")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textColor.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(chapters.enumerated()), id: \.element.id) { idx, chapter in
                                let isCurrent = currentChapterIndex == idx
                                Button {
                                    onSelect(chapter)
                                } label: {
                                    HStack(spacing: 12) {
                                        // 当前章节指示点
                                        Circle()
                                            .fill(isCurrent ? Color.orange : Color.clear)
                                            .frame(width: 6, height: 6)

                                        Text(chapter.title)
                                            .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                                            .foregroundColor(isCurrent ? Color.orange : theme.textColor.opacity(0.8))
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 13)
                                    .background(isCurrent ? theme.textColor.opacity(0.06) : Color.clear)
                                }
                                .id(idx)

                                if idx < chapters.count - 1 {
                                    Divider()
                                        .background(theme.textColor.opacity(0.07))
                                        .padding(.leading, 38)
                                }
                            }
                        }
                    }
                    .onAppear {
                        if let cur = currentChapterIndex {
                            proxy.scrollTo(cur, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(theme.background)
    }
}

// MARK: - 设置面板（底部 Sheet）
struct ReaderSettingsPanel: View {
    @Binding var textSize: Double
    @Binding var lineSpacing: Double
    @Binding var wrapLineSpacing: Double
    @Binding var theme: ReadingTheme
    @Binding var pageMode: PageMode
    let theme_color: ReadingTheme // 当前主题色用于面板自身配色
    var onShowDetail: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 把手 + 右上角详情按钮
            ZStack {
                Capsule()
                    .fill(theme_color.textColor.opacity(0.25))
                    .frame(width: 36, height: 4)
                if let onShowDetail {
                    HStack {
                        Spacer()
                        Button(action: onShowDetail) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundColor(theme_color.textColor.opacity(0.6))
                        }
                        .padding(.trailing, 16)
                    }
                }
            }
            .frame(height: 24)
            .padding(.top, 10)
            .padding(.bottom, 6)

            VStack(spacing: 20) {
                // 字体大小
                HStack(spacing: 14) {
                    Text("字")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 20)

                    Button {
                        textSize = max(12, textSize - 1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Slider(value: $textSize, in: 12...28, step: 1)
                        .tint(Color.orange)

                    Button {
                        textSize = min(28, textSize + 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Text("\(Int(textSize))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme_color.textColor)
                        .frame(width: 28)
                }

                // 行间距
                HStack(spacing: 14) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 20)

                    Button {
                        lineSpacing = max(4, lineSpacing - 2)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Slider(value: $lineSpacing, in: 4...20, step: 2)
                        .tint(Color.orange)

                    Button {
                        lineSpacing = min(20, lineSpacing + 2)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Text("\(Int(lineSpacing))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme_color.textColor)
                        .frame(width: 28)
                }

                // 自动分行行间距
                HStack(spacing: 14) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 20)

                    Button {
                        wrapLineSpacing = max(0, wrapLineSpacing - 2)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Slider(value: $wrapLineSpacing, in: 0...16, step: 2)
                        .tint(Color.orange)

                    Button {
                        wrapLineSpacing = min(16, wrapLineSpacing + 2)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Text("\(Int(wrapLineSpacing))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme_color.textColor)
                        .frame(width: 28)
                }

                // 背景主题选择
                HStack(spacing: 10) {
                    ForEach(ReadingTheme.allCases) { t in
                        Button {
                            theme = t
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(t.background)
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(theme == t ? Color.orange : t.textColor.opacity(0.2), lineWidth: theme == t ? 2 : 1)
                                        )
                                    Image(systemName: t.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(t.textColor)
                                }
                                Text(t.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(theme_color.textColor.opacity(0.7))
                            }
                        }
                        if t != ReadingTheme.allCases.last { Spacer() }
                    }
                }
                .padding(.horizontal, 8)

                // 翻页模式选择
                HStack(spacing: 10) {
                    Text("翻页")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 28)

                    ForEach(PageMode.allCases) { mode in
                        Button {
                            pageMode = mode
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(pageMode == mode ? Color.orange : theme_color.textColor.opacity(0.6))
                                Text(mode.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(pageMode == mode ? Color.orange : theme_color.textColor.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(pageMode == mode ? Color.orange.opacity(0.12) : theme_color.textColor.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(pageMode == mode ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(theme_color.background)
    }
}

// MARK: - 主阅读视图
struct BookReaderView: View {
    @Bindable var book: Book

    @Environment(\.dismiss) private var dismiss

    // 阅读设置
    @AppStorage("textSize") private var textSize: Double = 18
    @AppStorage("lineSpacing") private var lineSpacing: Double = 12
    @AppStorage("wrapLineSpacing") private var wrapLineSpacing: Double = 6
    @State private var theme: ReadingTheme = .white
    @AppStorage("pageMode") private var pageMode: PageMode = .horizontal

    // UI 状态
    @State private var showBars: Bool = false
    @State private var showTOC: Bool = false
    @State private var showSettings: Bool = false
    @State private var showSearch: Bool = false
    @State private var showBookDetail: Bool = false
    @State private var jumpToLineIndex: Int? = nil

    // 搜索状态
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []

    // 顶部状态栏
    @State private var currentTime: String = ""
    @State private var batteryLevel: Float = -1
    @State private var batteryState: UIDevice.BatteryState = .unknown

    // 进度 & 章节追踪
    @State private var readingProgress: Double = 0
    @State private var isDraggingSlider: Bool = false
    @State private var currentChapterIdx: Int = 0
    @State private var contentHeight: CGFloat = 0     // LazyVStack 总高度
    @State private var viewportHeight: CGFloat = 0    // ScrollView 视口高度
    @State private var viewportWidth: CGFloat = 0     // 视口宽度（点击翻页用）

    // 翻页模式状态
    @State private var pages: [PageData] = []
    @State private var currentPageIdx: Int = 0
    @State private var pageViewportSize: CGSize = .zero
    @State private var displayLines: [DisplayLine] = []

    // ── 预处理缓存（异步计算，避免每次 body 重算）────────────
    /// 按行分割后的文本，book.content 不变时只计算一次
    @State private var lines: [String] = []
    /// 章节列表，解析自 lines
    @State private var chapters: [Chapter] = []
    /// 章节行索引集合，O(1) 判断某行是否为章节标题
    @State private var chapterLineSet: Set<Int> = []
    /// 章节行号数组（已排序），用于二分查找
    @State private var chapterLineIndices: [Int] = []

    // MARK: - 计算属性（全部引用缓存，零重算）

    private var prevChapter: Chapter? {
        guard !chapters.isEmpty, currentChapterIdx > 0 else { return nil }
        return chapters[currentChapterIdx - 1]
    }

    private var nextChapter: Chapter? {
        guard !chapters.isEmpty, currentChapterIdx < chapters.count - 1 else { return nil }
        return chapters[currentChapterIdx + 1]
    }

    /// 当前章节内的页码信息："当前页/总页数"
    private var chapterPageLabel: String {
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
            // 滚动模式：根据进度估算当前行
            let currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
            let chapLines = chapEnd - chapStart
            let linesPerPage = max(1, Int(max(1, viewportHeight - 32) / (textSize * 1.2 + lineSpacing)))
            let totalPagesInChap = max(1, (chapLines + linesPerPage - 1) / linesPerPage)
            let lineInChap = max(0, min(currentLine - chapStart, chapLines - 1))
            let curPage = min(lineInChap / linesPerPage + 1, totalPagesInChap)
            return "\(curPage)/\(totalPagesInChap)"
        } else {
            // 翻页模式：精确计算
            guard !pages.isEmpty, !displayLines.isEmpty else { return "" }
            // 找出属于当前章节的所有页（通过 displayLine 的 originalLineIndex 判断）
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
    }

    /// 电池图标名
    private var batteryIconName: String {
        if batteryLevel < 0 { return "battery.100" }
        let isCharging = batteryState == .charging || batteryState == .full
        if isCharging { return "battery.100.bolt" }
        if batteryLevel > 0.75 { return "battery.100" }
        if batteryLevel > 0.50 { return "battery.75" }
        if batteryLevel > 0.25 { return "battery.50" }
        if batteryLevel > 0.10 { return "battery.25" }
        return "battery.0"
    }

    private var batteryLevelText: String {
        guard batteryLevel >= 0 else { return "--%" }
        return "\(Int(batteryLevel * 100))%"
    }

    private var batteryTintColor: Color {
        if batteryLevel >= 0 && batteryLevel <= 0.2 {
            return Color.red.opacity(0.5)
        }
        return theme.textColor.opacity(0.3)
    }

    // MARK: - 纯函数（不依赖 self 的 State）

    /// 二分查找：给定行号，返回所属章节索引 — O(log n)
    private func chapterIndex(for lineIdx: Int) -> Int {
        guard !chapterLineIndices.isEmpty else { return 0 }
        var lo = 0, hi = chapterLineIndices.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if chapterLineIndices[mid] <= lineIdx { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            theme.background.ignoresSafeArea()

            // ── 三段式布局：顶部栏 + 正文 + 底部栏 ──────────────
            VStack(spacing: 0) {
                if !showBars && !showSearch && !showTOC {
                    topStatusBar
                }

                switch pageMode {
                case .scroll:
                    scrollReadingView
                case .horizontal:
                    horizontalPagedView
                }

                if !showBars && !showSearch && !showTOC {
                    bottomStatusBar
                }
            }

            // ── 目录抽屉 ────────────────────────────────────────
            if showTOC {
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

            // ── 搜索覆盖层 ──────────────────────────────────────
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
        // ── 异步预处理：book.content 变化时才重新解析 ──────────
        .task(id: book.content) {
            await parseContent(book.content)
            // 恢复上次阅读位置
            if book.lastReadLineIndex > 0 && book.lastReadLineIndex < lines.count {
                jumpToLineIndex = book.lastReadLineIndex
                currentChapterIdx = chapterIndex(for: book.lastReadLineIndex)
                readingProgress = Double(book.lastReadLineIndex) / Double(max(1, lines.count - 1))
            }
        }
        .onDisappear {
            saveReadingPosition()
        }
        .task {
            UIDevice.current.isBatteryMonitoringEnabled = true
            while !Task.isCancelled {
                updateTimeAndBattery()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        // ── 翻页模式下：字号/行距/视口变化时重新分页 ──────────
        .onChange(of: textSize) { _, _ in rebuildPagesIfNeeded() }
        .onChange(of: lineSpacing) { _, _ in rebuildPagesIfNeeded() }
        .onChange(of: wrapLineSpacing) { _, _ in rebuildPagesIfNeeded() }
        .onChange(of: pageMode) { _, _ in rebuildPagesIfNeeded() }
        .onChange(of: pageViewportSize) { _, _ in rebuildPagesIfNeeded() }
    }

    // MARK: - 异步内容解析（在后台线程执行，避免阻塞主线程）
    @MainActor
    private func parseContent(_ content: String) async {
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
        lines              = parsed.0
        chapters           = parsed.1
        chapterLineSet     = parsed.2
        chapterLineIndices = parsed.3
        rebuildPagesIfNeeded()
    }

    // MARK: - 单行视图（拆出避免 body 类型推断超时）
    @ViewBuilder
    private func lineView(index: Int, line: String) -> some View {
        if chapterLineSet.contains(index) {
            // 章节标题行
            VStack(alignment: .leading, spacing: 6) {
                if index != 0 {
                    Divider()
                        .background(theme.textColor.opacity(0.1))
                        .padding(.bottom, 8)
                }
                Text(line.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: textSize + 3, weight: .bold))
                    .foregroundColor(theme.chapterColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, index == 0 ? 0 : 24)
                    .padding(.bottom, 16)
            }
            .id(index)
        } else {
            // 正文行
            Text(line.isEmpty ? "\n" : line)
                .font(.system(size: textSize))
                .foregroundColor(theme.textColor)
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, lineSpacing / 2)
                .id(index)
        }
    }

    // MARK: - 翻页模式下的单行视图
    @ViewBuilder
    private func displayLineView(_ dl: DisplayLine) -> some View {
        if dl.isChapter {
            lineView(index: dl.originalLineIndex, line: dl.text)
        } else {
            let topPad = dl.isFirstOfParagraph ? lineSpacing / 2 : wrapLineSpacing / 2
            let botPad = dl.isLastOfParagraph  ? lineSpacing / 2 : wrapLineSpacing / 2
            Text(dl.text)
                .font(.system(size: textSize))
                .foregroundColor(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, topPad)
                .padding(.bottom, botPad)
        }
    }

    // MARK: - 顶部状态栏（常驻）
    @ViewBuilder
    private var topStatusBar: some View {
        HStack(spacing: 6) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textColor.opacity(0.3))
            }

            if !chapters.isEmpty && currentChapterIdx < chapters.count {
                Text(chapters[currentChapterIdx].title)
                    .font(.system(size: 10))
                    .foregroundColor(theme.textColor.opacity(0.3))
                    .lineLimit(1)
            }

            if !chapterPageLabel.isEmpty {
                Text(chapterPageLabel)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(theme.textColor.opacity(0.3))
                    .fixedSize()
            }

            Text("\(Int(readingProgress * 100))%")
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(theme.textColor.opacity(0.3))
                .fixedSize()

            Spacer()

            Text(currentTime)
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(theme.textColor.opacity(0.3))
                .fixedSize()

            HStack(spacing: 2) {
                Image(systemName: batteryIconName)
                    .font(.system(size: 10))
                    .foregroundColor(batteryTintColor)
                Text(batteryLevelText)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(theme.textColor.opacity(0.3))
            }
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.top, 1)
        .padding(.bottom, 2)
    }

    // MARK: - 底部状态栏（常驻）
    @ViewBuilder
    private var bottomStatusBar: some View {
        HStack(spacing: 6) {
            if !chapters.isEmpty && currentChapterIdx < chapters.count {
                Text(chapters[currentChapterIdx].title)
                    .font(.system(size: 10))
                    .foregroundColor(theme.textColor.opacity(0.3))
                    .lineLimit(1)
            }

            if !chapterPageLabel.isEmpty {
                Text(chapterPageLabel)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(theme.textColor.opacity(0.3))
                    .fixedSize()
            }

            Text("\(Int(readingProgress * 100))%")
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(theme.textColor.opacity(0.3))
                .fixedSize()

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    // MARK: - 导航栏 + 工具栏覆盖层
    @ViewBuilder
    private var barsOverlay: some View {
        // 顶部导航栏
        VStack {
            HStack(spacing: 4) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }

                Text(book.displayTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSearch = true
                        showBars = false
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(10)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(theme.barBackground.opacity(0.92).ignoresSafeArea(edges: .top))
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(5)

        // 底部工具栏
        VStack {
            Spacer()
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.12))

                progressSliderRow

                Divider().background(Color.white.opacity(0.08))

                bottomButtonRow

                if showSettings {
                    ReaderSettingsPanel(
                        textSize: $textSize,
                        lineSpacing: $lineSpacing,
                        wrapLineSpacing: $wrapLineSpacing,
                        theme: $theme,
                        pageMode: $pageMode,
                        theme_color: theme,
                        onShowDetail: {
                            withAnimation { showSettings = false; showBars = false }
                            showBookDetail = true
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(5)
    }

    // MARK: - 进度条行
    @ViewBuilder
    private var progressSliderRow: some View {
        HStack(spacing: 10) {
            Button {
                if let ch = prevChapter {
                    jumpToLineIndex = ch.lineIndex
                    currentChapterIdx = chapterIndex(for: ch.lineIndex)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(prevChapter == nil ? .white.opacity(0.2) : .white.opacity(0.85))
                    .frame(width: 36, height: 36)
            }
            .disabled(prevChapter == nil)

            VStack(spacing: 3) {
                Slider(
                    value: $readingProgress,
                    in: 0...1,
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            if pageMode == .scroll {
                                let target = Int(readingProgress * Double(max(1, lines.count - 1)))
                                jumpToLineIndex = target
                                currentChapterIdx = chapterIndex(for: target)
                            } else if !pages.isEmpty, !displayLines.isEmpty {
                                let targetPage = Int(readingProgress * Double(max(1, pages.count - 1)))
                                currentPageIdx = min(targetPage, pages.count - 1)
                                let dlIdx = pages[currentPageIdx].lineRange.lowerBound
                                let firstLine = displayLines[min(dlIdx, displayLines.count - 1)].originalLineIndex
                                currentChapterIdx = chapterIndex(for: firstLine)
                            }
                        }
                    }
                )
                .tint(Color.orange)

                HStack {
                    Text(chapters.isEmpty ? "共\(lines.count)行" :
                         (currentChapterIdx < chapters.count ?
                          chapters[currentChapterIdx].title : ""))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(readingProgress * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            Button {
                if let ch = nextChapter {
                    jumpToLineIndex = ch.lineIndex
                    currentChapterIdx = chapterIndex(for: ch.lineIndex)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(nextChapter == nil ? .white.opacity(0.2) : .white.opacity(0.85))
                    .frame(width: 36, height: 36)
            }
            .disabled(nextChapter == nil)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(theme.barBackground.opacity(0.92))
    }

    // MARK: - 底部功能按钮行
    @ViewBuilder
    private var bottomButtonRow: some View {
        HStack(spacing: 0) {
            toolBarButton(icon: "list.bullet", label: "目录") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showTOC.toggle(); showBars = false
                }
            }
            Spacer()
            toolBarButton(icon: "textformat", label: "设置") {
                withAnimation(.spring(response: 0.3)) { showSettings.toggle() }
            }
            Spacer()
            toolBarButton(icon: "sun.min", label: "亮度") { }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "bookmark")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.7))
                Text(!chapters.isEmpty ? "\(chapters.count)章" : "无章节")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(minWidth: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(theme.barBackground.opacity(0.92).ignoresSafeArea(edges: .bottom))
    }

    // MARK: - 工具栏按钮
    @ViewBuilder
    private func toolBarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.85))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(minWidth: 44)
        }
    }

    // MARK: - 滚动阅读视图
    @ViewBuilder
    private var scrollReadingView: some View {
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
                            .preference(key: ScrollContentHeightKey.self,
                                        value: inner.size.height)
                            .preference(key: ScrollOffsetKey.self,
                                        value: inner.frame(in: .named("scroll")).minY)
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
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    handleTapZone(at: value.location, viewWidth: viewportWidth)
                }
        )
    }

    // MARK: - 翻页阅读视图（水平）
    @ViewBuilder
    private var horizontalPagedView: some View {
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
            }
            .onChange(of: jumpToLineIndex) { _, newIdx in
                guard let idx = newIdx else { return }
                // 将逻辑行索引映射到显示行索引，再查找对应页
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
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    handleTapZone(at: value.location, viewWidth: pageViewportSize.width)
                }
        )
    }

    // MARK: - 点击翻页
    private func handleTapZone(at location: CGPoint, viewWidth: CGFloat) {
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

    private func tapPreviousPage() {
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

    private func tapNextPage() {
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

    // MARK: - 单页内容视图
    @ViewBuilder
    private func pageContentView(page: PageData) -> some View {
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

    // MARK: - 分页计算
    /// 根据视口大小、字号、行距，先将逻辑行拆分为视觉行（displayLines），再分页
    private func rebuildPagesIfNeeded() {
        guard pageMode != .scroll else {
            pages = []
            displayLines = []
            return
        }
        guard !lines.isEmpty else {
            pages = []
            displayLines = []
            return
        }

        let vpHeight = pageViewportSize.height
        guard vpHeight > 100 else {
            pages = []
            displayLines = []
            return
        }

        let usableHeight = vpHeight - 0  // 上下 padding (top 0 + bottom 0)
        let usableWidth = max(1, pageViewportSize.width - 40) // 左右 padding 各 20
        let fontLineH = textSize * 1.2
        let chapterFontLineH = (textSize + 3) * 1.2
        let avgCharWidth: CGFloat = textSize
        let charsPerVisualLine = max(1, Int(usableWidth / avgCharWidth))
        let avgChapterCharWidth: CGFloat = textSize + 3
        let charsPerChapterLine = max(1, Int(usableWidth / avgChapterCharWidth))

        // ── 第一步：将逻辑行拆分为显示行（视觉行）──────────
        var dLines: [DisplayLine] = []
        for i in 0..<lines.count {
            let isChap = chapterLineSet.contains(i)
            let text = lines[i]

            if isChap {
                // 章节标题保持为单条显示行（通常较短）
                dLines.append(DisplayLine(text: text, isChapter: true, originalLineIndex: i, isFirstOfParagraph: true, isLastOfParagraph: true))
            } else {
                let charCount = text.count
                if charCount <= charsPerVisualLine {
                    dLines.append(DisplayLine(text: text, isChapter: false, originalLineIndex: i, isFirstOfParagraph: true, isLastOfParagraph: true))
                } else {
                    // 拆分为多条视觉行
                    var segments: [String] = []
                    var startIdx = text.startIndex
                    while startIdx < text.endIndex {
                        let endIdx = text.index(startIdx, offsetBy: charsPerVisualLine, limitedBy: text.endIndex) ?? text.endIndex
                        segments.append(String(text[startIdx..<endIdx]))
                        startIdx = endIdx
                    }
                    for (si, seg) in segments.enumerated() {
                        dLines.append(DisplayLine(text: seg, isChapter: false, originalLineIndex: i, isFirstOfParagraph: si == 0, isLastOfParagraph: si == segments.count - 1))
                    }
                }
            }
        }
        displayLines = dLines

        // ── 第二步：基于显示行进行分页──────────────────────
        // 行高 = fontLineH + topPad + botPad
        // 段落独行(first+last): fontLineH + lineSpacing
        // 段落首行(first only): fontLineH + lineSpacing/2 + wrapLineSpacing/2
        // 段落中间行:          fontLineH + wrapLineSpacing
        // 段落末行(last only):  fontLineH + wrapLineSpacing/2 + lineSpacing/2
        let soloLineH      = fontLineH + lineSpacing
        let firstLineH     = fontLineH + lineSpacing / 2 + wrapLineSpacing / 2
        let middleLineH    = fontLineH + wrapLineSpacing
        let lastLineH      = fontLineH + wrapLineSpacing / 2 + lineSpacing / 2

        var result: [PageData] = []
        var pageStart = 0
        var accHeight: CGFloat = 0
        var pageId = 0

        for i in 0..<dLines.count {
            let dl = dLines[i]
            let effectiveH: CGFloat
            if dl.isChapter {
                let charCount = dl.text.trimmingCharacters(in: .whitespaces).count
                let visualLines = max(1, Int(ceil(Double(charCount) / Double(charsPerChapterLine))))
                effectiveH = CGFloat(visualLines) * chapterFontLineH + 49
            } else {
                if dl.isFirstOfParagraph && dl.isLastOfParagraph {
                    effectiveH = soloLineH
                } else if dl.isFirstOfParagraph {
                    effectiveH = firstLineH
                } else if dl.isLastOfParagraph {
                    effectiveH = lastLineH
                } else {
                    effectiveH = middleLineH
                }
            }

            // 章节标题处强制分页
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

        let oldPageIdx = currentPageIdx
        pages = result

        if !result.isEmpty {
            let targetLine = Int(readingProgress * Double(max(1, lines.count - 1)))
            if let dlIdx = dLines.firstIndex(where: { $0.originalLineIndex >= targetLine }),
               let newPageIdx = result.firstIndex(where: { $0.lineRange.contains(dlIdx) }) {
                currentPageIdx = newPageIdx
            } else {
                currentPageIdx = min(oldPageIdx, result.count - 1)
            }
        }
    }

    // MARK: - 搜索覆盖视图
    @ViewBuilder
    private var searchOverlayView: some View {
        VStack(spacing: 0) {
            // 搜索栏
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

            // 搜索结果列表
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
                // 结果数量
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

    // MARK: - 搜索结果卡片
    @ViewBuilder
    private func searchResultCard(_ result: SearchResult) -> some View {
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
                // 章节标签
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.orange)
                    Text(result.chapterName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.orange)
                    Spacer()
                }

                // 匹配文本（高亮关键字）
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

    // MARK: - 高亮关键字文本
    private func highlightedText(_ text: String, keyword: String) -> Text {
        guard !keyword.isEmpty else {
            return Text(text).foregroundColor(theme.textColor.opacity(0.8))
        }
        let lowText = text.lowercased()
        let lowKey = keyword.lowercased()
        var attributed = AttributedString()
        var searchStart = lowText.startIndex

        while let range = lowText.range(of: lowKey, range: searchStart..<lowText.endIndex) {
            // 关键字前的部分
            var before = AttributedString(text[searchStart..<range.lowerBound])
            before.foregroundColor = theme.textColor.opacity(0.75)
            attributed.append(before)
            // 关键字部分高亮
            var matched = AttributedString(text[range.lowerBound..<range.upperBound])
            matched.foregroundColor = Color.orange
            matched.font = .boldSystemFont(ofSize: 14)
            attributed.append(matched)
            searchStart = range.upperBound
        }
        // 剩余部分
        if searchStart < lowText.endIndex {
            var tail = AttributedString(text[searchStart..<text.endIndex])
            tail.foregroundColor = theme.textColor.opacity(0.75)
            attributed.append(tail)
        }
        return Text(attributed)
    }

    // MARK: - 保存阅读位置
    private func saveReadingPosition() {
        guard !lines.isEmpty else { return }
        let currentLine: Int
        if pageMode == .scroll {
            currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
        } else if !pages.isEmpty, currentPageIdx < pages.count, !displayLines.isEmpty {
            let dlIdx = pages[currentPageIdx].lineRange.lowerBound
            currentLine = displayLines[min(dlIdx, displayLines.count - 1)].originalLineIndex
        } else {
            currentLine = Int(readingProgress * Double(max(1, lines.count - 1)))
        }
        book.lastReadLineIndex = currentLine
    }

    // MARK: - 更新时间与电量
    private func updateTimeAndBattery() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
        let currentBatteryLevel = UIDevice.current.batteryLevel
        if currentBatteryLevel >= 0 {
            batteryLevel = currentBatteryLevel
        }
        batteryState = UIDevice.current.batteryState
    }

    // MARK: - 执行搜索
    private func performSearch() {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            searchResults = []
            return
        }
        let lowKeyword = keyword.lowercased()
        var results: [SearchResult] = []
        for (index, line) in lines.enumerated() {
            if line.lowercased().contains(lowKeyword) {
                let chapIdx = chapterIndex(for: index)
                let chapName: String
                if chapters.isEmpty {
                    chapName = "第\(index + 1)行"
                } else if chapIdx < chapters.count {
                    chapName = chapters[chapIdx].title
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
        searchResults = results
    }
}
