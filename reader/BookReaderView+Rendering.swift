import SwiftUI

extension BookReaderView {
    @ViewBuilder
    func lineView(index: Int, line: String) -> some View {
        if chapterLineSet.contains(index) {
            VStack(alignment: .leading, spacing: 6) {
                if index != 0 {
                    Divider()
                        .background(theme.textColor.opacity(0.1))
                        .padding(.bottom, 8)
                }

                Text(line.trimmingCharacters(in: .whitespaces))
                    .font(chapterFont(size: textSize + 3))
                    .foregroundColor(theme.chapterColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, index == 0 ? 0 : 24)
                    .padding(.bottom, 16)
            }
            .id(index)
        } else {
            Text(line.isEmpty ? "\n" : line)
                .font(bodyFont(size: textSize))
                .foregroundColor(theme.textColor)
                .lineSpacing(wrapLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, lineSpacing / 2)
                .id(index)
        }
    }

    @ViewBuilder
    func displayLineView(_ dl: DisplayLine) -> some View {
        if dl.isChapter {
            lineView(index: dl.originalLineIndex, line: dl.text)
        } else {
            let topPad = dl.isFirstOfParagraph ? lineSpacing / 2 : wrapLineSpacing / 2
            let botPad = dl.isLastOfParagraph ? lineSpacing / 2 : wrapLineSpacing / 2
            Text(dl.text)
                .font(bodyFont(size: textSize))
                .foregroundColor(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, topPad)
                .padding(.bottom, botPad)
        }
    }

    @ViewBuilder
    var topStatusBar: some View {
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

    @ViewBuilder
    var bottomStatusBar: some View {
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

    @ViewBuilder
    var barsOverlay: some View {
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
                        fontFamily: Binding(
                            get: { ReadingFontFamily(rawValue: fontFamilyRawValue) ?? .system },
                            set: { fontFamilyRawValue = $0.rawValue }
                        ),
                        keepScreenOn: $keepScreenOn,
                        theme_color: theme,
                        onShowDetail: {
                            withAnimation {
                                showSettings = false
                                showBars = false
                            }
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

    @ViewBuilder
    var progressSliderRow: some View {
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
                    Text(chapters.isEmpty ? "共\(lines.count)行" : (currentChapterIdx < chapters.count ? chapters[currentChapterIdx].title : ""))
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

    @ViewBuilder
    var bottomButtonRow: some View {
        HStack(spacing: 0) {
            toolBarButton(icon: "list.bullet", label: "目录") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showTOC.toggle()
                    showBars = false
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

    @ViewBuilder
    func toolBarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
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
}
