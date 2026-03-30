//
//  ContentView.swift
//  neader
//
//  Created by Jim Li on 23/3/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    @State private var showDocumentPicker = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedBook: Book?

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("书架为空")
                            .font(.headline)

                        Text("点击下方按钮导入txt文件开始阅读")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 16) {
                            ForEach(books) { book in
                                NavigationLink(destination: BookReaderView(book: book)) {
                                    VStack(alignment: .center, spacing: 12) {
                                        // 书籍封面模拟
                                        ZStack {
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(hue: Double(book.title.hashValue % 100) / 100, saturation: 0.7, brightness: 0.8),
                                                    Color(hue: Double((book.title.hashValue + 50) % 100) / 100, saturation: 0.7, brightness: 0.9)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )

                                            VStack(spacing: 8) {
                                                Image(systemName: "book.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.white)

                                                Text(book.title)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .lineLimit(2)
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal, 8)
                                            }
                                            .padding()
                                        }
                                        .frame(height: 140)
                                        .cornerRadius(8)
                                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                                        // 书籍信息
                                        VStack(alignment: .center, spacing: 4) {
                                            Text(book.author)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)

                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.caption2)
                                                Text(book.addDate.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        selectedBook = book
                                    } label: {
                                        Label("详情", systemImage: "info.circle")
                                    }
                                    Button(role: .destructive) {
                                        if let index = books.firstIndex(where: { $0.id == book.id }) {
                                            modelContext.delete(books[index])
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("书架")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showDocumentPicker = true }) {
                        Label("导入", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url in
                    importBook(from: url)
                }
            }
            .alert("导入失败", isPresented: $showError, presenting: errorMessage) { _ in
                Button("确定") { }
            } message: { message in
                Text(message)
            }
            .sheet(item: $selectedBook) { book in
                NavigationStack {
                    BookDetailView(book: book)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") { selectedBook = nil }
                            }
                        }
                }
            }
        }
    }

    private func importBook(from url: URL) {
        do {
            // 开始访问安全的文件URL
            let isSecureURL = url.startAccessingSecurityScopedResource()
            defer {
                if isSecureURL {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw NSError(domain: "FileNotFound", code: -1, userInfo: [NSLocalizedDescriptionKey: "文件不存在"])
            }

            // 读取文件原始数据
            let data = try Data(contentsOf: url)

            // 按优先级尝试常见编码：UTF-8、GBK/GB18030、Big5、UTF-16
            let encodings: [String.Encoding] = [
                .utf8,
                String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),  // GBK / GB2312 / GB18030
                String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.big5.rawValue))),            // Big5（繁体）
                .utf16,
                .isoLatin1
            ]

            var content: String?
            for encoding in encodings {
                if let str = String(data: data, encoding: encoding),
                   !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    content = str
                    break
                }
            }

            guard let content = content else {
                throw NSError(domain: "EncodingError", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "无法识别文件编码，请将文件转换为 UTF-8 格式后重试"])
            }

            // 检查内容是否为空
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "EmptyFile", code: -2, userInfo: [NSLocalizedDescriptionKey: "文件内容为空"])
            }

            // 获取文件名作为书籍标题
            let fileName = url.deletingPathExtension().lastPathComponent

            // 创建新书籍
            let newBook = Book(title: fileName, author: "未知", content: content)
            modelContext.insert(newBook)

            try modelContext.save()
            showDocumentPicker = false
        } catch {
            errorMessage = "导入失败: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
