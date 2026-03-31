import Foundation
import SwiftData

struct BookImportService {
    static func makeBook(from url: URL) throws -> Book {
        let isSecureURL = url.startAccessingSecurityScopedResource()
        defer {
            if isSecureURL {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "FileNotFound",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "文件不存在"]
            )
        }

        let data = try Data(contentsOf: url)
        let encodings: [String.Encoding] = [
            .utf8,
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )),
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.big5.rawValue)
            )),
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

        guard let content else {
            throw NSError(
                domain: "EncodingError",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "无法识别文件编码，请将文件转换为 UTF-8 格式后重试"]
            )
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "EmptyFile",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "文件内容为空"]
            )
        }

        let fileName = url.deletingPathExtension().lastPathComponent
        return Book(title: fileName, author: "未知", content: content)
    }

    static func importBook(from url: URL, modelContext: ModelContext) throws {
        let newBook = try makeBook(from: url)
        modelContext.insert(newBook)
        try modelContext.save()
    }
}
