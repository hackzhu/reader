//
//  BookDetailView.swift
//  neader
//
//  Created by Jim Li on 23/3/2026.
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    let book: Book

    @Environment(\.dismiss) private var dismiss

    // 缓存的计算值（避免在视图更新时反复计算大文本）
    @State private var wordCount: Int = 0
    @State private var lineCount: Int = 0
    @State private var chapterCount: Int = 0

    private static let chapterRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(第[零一二三四五六七八九十百千万\d]+[章节卷集部回篇]|Chapter\s*\d+|CHAPTER\s*\d+)"#,
        options: .anchorsMatchLines
    )

    private var readingProgressPercent: Int {
        guard lineCount > 0 else { return 0 }
        return min(100, Int(Double(book.lastReadLineIndex) / Double(lineCount) * 100))
    }

    private var coverColors: [Color] {
        [
            Color(hue: Double(book.title.hashValue % 100) / 100, saturation: 0.7, brightness: 0.8),
            Color(hue: Double((book.title.hashValue + 50) % 100) / 100, saturation: 0.7, brightness: 0.9)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 封面区域
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        gradient: Gradient(colors: coverColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 260)

                    VStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.9))

                        Text(book.displayTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Text(book.author)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 28)
                }

                // 详情卡片
                VStack(spacing: 12) {
                    infoCard {
                        infoRow(icon: "text.book.closed", label: "书名", value: book.displayTitle)
                        Divider().padding(.leading, 44)
                        infoRow(icon: "person", label: "作者", value: book.author)
                        Divider().padding(.leading, 44)
                        infoRow(icon: "calendar", label: "添加时间",
                                value: book.addDate.formatted(date: .abbreviated, time: .shortened))
                    }

                    infoCard {
                        infoRow(icon: "doc.text", label: "字数",
                                value: formatNumber(wordCount) + " 字")
                        Divider().padding(.leading, 44)
                        infoRow(icon: "list.number", label: "行数",
                                value: formatNumber(lineCount) + " 行")
                        if chapterCount > 0 {
                            Divider().padding(.leading, 44)
                            infoRow(icon: "list.bullet.indent", label: "章节数",
                                    value: "\(chapterCount) 章")
                        }
                    }

                    infoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "book.pages")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                Text("阅读进度")
                                    .font(.system(size: 15))
                                Spacer()
                                Text("\(readingProgressPercent)%")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            ProgressView(value: Double(readingProgressPercent), total: 100)
                                .tint(.orange)
                                .padding(.leading, 36)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .task(id: book.id) {
            let content = book.content
            let wc = await Task.detached(priority: .userInitiated) {
                content.filter { !$0.isWhitespace }.count
            }.value
            let lc = await Task.detached(priority: .userInitiated) {
                content.split(separator: "\n", omittingEmptySubsequences: false).count
            }.value
            let cc = await Task.detached(priority: .userInitiated) {
                guard let regex = BookDetailView.chapterRegex else { return 0 }
                let range = NSRange(content.startIndex..., in: content)
                return regex.numberOfMatches(in: content, range: range)
            }.value
            wordCount = wc
            lineCount = lc
            chapterCount = cc
        }
    }

    // MARK: - 辅助视图

    @ViewBuilder
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book(title: "《西游记》", author: "吴承恩", content: String(repeating: "孙悟空\n", count: 1000)))
    }
    .modelContainer(for: Book.self, inMemory: true)
}
