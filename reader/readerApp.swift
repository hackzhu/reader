//
//  neaderApp.swift
//  neader
//
//  Created by Jim Li on 23/3/2026.
//

import SwiftUI
import SwiftData

@main
struct neaderApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // 初始化时添加测试数据
        addSampleBooksIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private func addSampleBooksIfNeeded() {
        // 检查是否已经添加过样本书籍
        let descriptor = FetchDescriptor<Book>()
        do {
            let existingBooks = try sharedModelContainer.mainContext.fetch(descriptor)

            // 如果书架为空，添加样本书籍
            if existingBooks.isEmpty {
                for sampleBook in SampleBooks.samples {
                    sharedModelContainer.mainContext.insert(sampleBook)
                }
                try sharedModelContainer.mainContext.save()
            }
        } catch {
            print("Error adding sample books: \(error)")
        }
    }
}
