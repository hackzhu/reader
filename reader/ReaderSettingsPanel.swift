import SwiftUI

// MARK: - 设置面板（底部 Sheet）
struct ReaderSettingsPanel: View {
    @Binding var textSize: Double
    @Binding var lineSpacing: Double
    @Binding var wrapLineSpacing: Double
    @Binding var theme: ReadingTheme
    @Binding var pageMode: PageMode
    @Binding var fontFamily: ReadingFontFamily
    @Binding var keepScreenOn: Bool
    let theme_color: ReadingTheme // 当前主题色用于面板自身配色
    var onShowDetail: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 把手 + 右上角详情按钮
            ZStack {
                Capsule()
                    .fill(theme_color.textColor.opacity(0.25))
                    .frame(width: 36, height: 4)
                if let onShowDetail {
                    HStack {
                        Spacer()
                        Button(action: onShowDetail) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundColor(theme_color.textColor.opacity(0.6))
                        }
                        .padding(.trailing, 16)
                    }
                }
            }
            .frame(height: 24)
            .padding(.top, 10)
            .padding(.bottom, 6)

            VStack(spacing: 20) {
                // 字体大小
                HStack(spacing: 14) {
                    Text("字")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 20)

                    Button {
                        textSize = max(12, textSize - 1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Slider(value: $textSize, in: 12...28, step: 1)
                        .tint(Color.orange)

                    Button {
                        textSize = min(28, textSize + 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Text("\(Int(textSize))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme_color.textColor)
                        .frame(width: 28)
                }

                // 行间距
                HStack(spacing: 14) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 20)

                    Button {
                        lineSpacing = max(4, lineSpacing - 2)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Slider(value: $lineSpacing, in: 4...20, step: 2)
                        .tint(Color.orange)

                    Button {
                        lineSpacing = min(20, lineSpacing + 2)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Text("\(Int(lineSpacing))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme_color.textColor)
                        .frame(width: 28)
                }

                // 自动分行行间距
                HStack(spacing: 14) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 20)

                    Button {
                        wrapLineSpacing = max(0, wrapLineSpacing - 2)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Slider(value: $wrapLineSpacing, in: 0...16, step: 2)
                        .tint(Color.orange)

                    Button {
                        wrapLineSpacing = min(16, wrapLineSpacing + 2)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                            .background(theme_color.textColor.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(theme_color.textColor)
                    }

                    Text("\(Int(wrapLineSpacing))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme_color.textColor)
                        .frame(width: 28)
                }

                // 背景主题选择
                HStack(spacing: 10) {
                    ForEach(ReadingTheme.allCases) { t in
                        Button {
                            theme = t
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(t.background)
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(theme == t ? Color.orange : t.textColor.opacity(0.2), lineWidth: theme == t ? 2 : 1)
                                        )
                                    Image(systemName: t.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(t.textColor)
                                }
                                Text(t.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(theme_color.textColor.opacity(0.7))
                            }
                        }
                        if t != ReadingTheme.allCases.last { Spacer() }
                    }
                }
                .padding(.horizontal, 8)

                // 翻页模式选择
                HStack(spacing: 10) {
                    Text("翻页")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 28)

                    ForEach(PageMode.allCases) { mode in
                        Button {
                            pageMode = mode
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(pageMode == mode ? Color.orange : theme_color.textColor.opacity(0.6))
                                Text(mode.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(pageMode == mode ? Color.orange : theme_color.textColor.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(pageMode == mode ? Color.orange.opacity(0.12) : theme_color.textColor.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(pageMode == mode ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }

                // 字体家族
                HStack(spacing: 10) {
                    Text("字体")
                        .font(.system(size: 13))
                        .foregroundColor(theme_color.textColor.opacity(0.6))
                        .frame(width: 28)

                    ForEach(ReadingFontFamily.allCases) { family in
                        Button {
                            fontFamily = family
                        } label: {
                            Text(family.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(fontFamily == family ? Color.orange : theme_color.textColor.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(fontFamily == family ? Color.orange.opacity(0.12) : theme_color.textColor.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(fontFamily == family ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                        }
                    }
                }

                Toggle(isOn: $keepScreenOn) {
                    HStack(spacing: 8) {
                        Image(systemName: "light.max")
                            .font(.system(size: 13))
                            .foregroundColor(theme_color.textColor.opacity(0.6))
                        Text("保持屏幕常亮")
                            .font(.system(size: 13))
                            .foregroundColor(theme_color.textColor.opacity(0.8))
                    }
                }
                .toggleStyle(.switch)
                .tint(.orange)

                Button {
                    textSize = 18
                    lineSpacing = 12
                    wrapLineSpacing = 6
                    fontFamily = .system
                } label: {
                    Text("恢复默认排版")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(theme_color.background)
    }
}
