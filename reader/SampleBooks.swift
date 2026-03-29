//
//  SampleBooks.swift
//  neader
//
//  Created by Jim Li on 23/3/2026.
//

import Foundation

struct SampleBooks {
    static let samples: [Book] = {
        var books: [Book] = []
        if let url = Bundle.main.url(forResource: "西游记", withExtension: "txt"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            books.append(Book(title: "西游记", author: "吴承恩", content: content))
        }
        return books
    }()
}
