import SwiftUI

struct BookshelfBookCard: View {
    let book: Book

    private var coverGradient: [Color] {
        [
            Color(hue: Double(book.title.hashValue % 100) / 100, saturation: 0.7, brightness: 0.8),
            Color(hue: Double((book.title.hashValue + 50) % 100) / 100, saturation: 0.7, brightness: 0.9)
        ]
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: coverGradient),
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

            VStack(alignment: .center, spacing: 4) {
                Text(book.displayTitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
    }
}
