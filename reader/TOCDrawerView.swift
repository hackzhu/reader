import SwiftUI

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
