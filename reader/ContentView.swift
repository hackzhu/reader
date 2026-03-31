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
    @Query(sort: \Book.lastOpenDate, order: .reverse) private var books: [Book]
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
                                    BookshelfBookCard(book: book)
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
            try BookImportService.importBook(from: url, modelContext: modelContext)
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
