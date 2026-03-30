//
//  Item.swift
//  neader
//
//  Created by Jim Li on 23/3/2026.
//

import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var content: String
    var addDate: Date
    var currentPage: Int = 0
    var totalPages: Int = 0
    var lastReadLineIndex: Int = 0
    var lastOpenDate: Date = Date()

    init(title: String, author: String = "未知", content: String) {
        self.title = title
        self.author = author
        self.content = content
        self.addDate = Date()
        self.totalPages = content.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    /// 从 title 中提取书名号《》内的文字；若无书名号则返回 nil
    var realTitle: String? {
        guard let start = title.firstIndex(of: "《"),
              let end = title.firstIndex(of: "》"),
              start < end else {
            return nil
        }
        let inner = String(title[title.index(after: start)..<end])
        return inner.isEmpty ? nil : inner
    }

    /// 优先返回 realTitle，否则返回完整 title
    var displayTitle: String {
        realTitle ?? title
    }
}
