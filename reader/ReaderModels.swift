import SwiftUI
import Foundation

enum ReadingTheme: String, CaseIterable, Identifiable {
    case white = "白天"
    case eye = "护眼"
    case wheat = "暖黄"
    case night = "夜间"

    var id: String { rawValue }

    var background: Color {
        switch self {
        case .white: return Color(red: 0.98, green: 0.97, blue: 0.95)
        case .eye: return Color(red: 0.84, green: 0.92, blue: 0.82)
        case .wheat: return Color(red: 0.96, green: 0.91, blue: 0.78)
        case .night: return Color(red: 0.11, green: 0.11, blue: 0.13)
        }
    }

    var textColor: Color {
        switch self {
        case .white: return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .eye: return Color(red: 0.17, green: 0.26, blue: 0.17)
        case .wheat: return Color(red: 0.28, green: 0.20, blue: 0.10)
        case .night: return Color(red: 0.78, green: 0.78, blue: 0.80)
        }
    }

    var chapterColor: Color {
        switch self {
        case .white: return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .eye: return Color(red: 0.10, green: 0.22, blue: 0.10)
        case .wheat: return Color(red: 0.22, green: 0.14, blue: 0.04)
        case .night: return Color(red: 0.95, green: 0.95, blue: 0.96)
        }
    }

    var barBackground: Color {
        switch self {
        case .white: return Color(red: 0.14, green: 0.14, blue: 0.14)
        case .eye: return Color(red: 0.10, green: 0.18, blue: 0.10)
        case .wheat: return Color(red: 0.24, green: 0.16, blue: 0.06)
        case .night: return Color(red: 0.07, green: 0.07, blue: 0.09)
        }
    }

    var icon: String {
        switch self {
        case .white: return "sun.max"
        case .eye: return "leaf"
        case .wheat: return "cup.and.saucer"
        case .night: return "moon.stars"
        }
    }
}

struct Chapter: Identifiable {
    let id = UUID()
    let title: String
    let lineIndex: Int
}

enum PageMode: String, CaseIterable, Identifiable {
    case scroll = "滚动"
    case horizontal = "左右"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scroll: return "scroll"
        case .horizontal: return "arrow.left.and.right"
        }
    }
}

enum ReadingFontFamily: String, CaseIterable, Identifiable {
    case system = "系统"
    case song = "宋体"
    case kai = "楷体"
    case hei = "黑体"
    case fang = "仿宋"

    var id: String { rawValue }

    var postScriptName: String? {
        switch self {
        case .system: return nil
        case .song: return "Songti SC"
        case .kai: return "Kaiti SC"
        case .hei: return "Heiti SC"
        case .fang: return "STFangsong"
        }
    }
}

struct PageData: Identifiable, Equatable, Sendable {
    let id: Int
    let lineRange: Range<Int>

    static func == (lhs: PageData, rhs: PageData) -> Bool {
        lhs.id == rhs.id
    }
}

struct DisplayLine: Sendable {
    let text: String
    let isChapter: Bool
    let originalLineIndex: Int
    let isFirstOfParagraph: Bool
    let isLastOfParagraph: Bool
}

struct SearchResult: Identifiable {
    let id = UUID()
    let lineIndex: Int
    let lineText: String
    let chapterName: String
    let keyword: String
}
