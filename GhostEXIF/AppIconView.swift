import SwiftUI

struct AppIconView: View {
    var body: some View {
        ZStack {
            // 1. Background
            Color.black

            // 2. Circular Radar Grid
            Circle()
                .stroke(Theme.matrixGreen.opacity(0.15), lineWidth: 1)
                .frame(width: 800)
            Circle()
                .stroke(Theme.matrixGreen.opacity(0.1), lineWidth: 1)
                .frame(width: 600)
            Circle()
                .stroke(Theme.matrixGreen.opacity(0.05), lineWidth: 1)
                .frame(width: 400)

            // Vertical/Horizontal Grid Lines
            Rectangle()
                .fill(Theme.matrixGreen.opacity(0.05))
                .frame(width: 1, height: 1024)
            Rectangle()
                .fill(Theme.matrixGreen.opacity(0.05))
                .frame(width: 1024, height: 1)

            // 3. Stylized "X" Node
            ZStack {
                // Glow effect
                Text("X")
                    .font(Theme.nasalizationFont(size: 600))
                    .foregroundColor(Theme.matrixGreen)
                    .blur(radius: 20)
                    .opacity(0.5)

                // Main "X"
                Text("X")
                    .font(Theme.nasalizationFont(size: 600))
                    .foregroundColor(Theme.matrixGreen)
                    .overlay(
                        // Digital segments effect
                        VStack(spacing: 40) {
                            ForEach(0..<15) { _ in
                                Rectangle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(height: 2)
                            }
                        }
                        .mask(Text("X").font(Theme.nasalizationFont(size: 600)))
                    )
            }

            // 4. Corner "Sync" Brackets
            Group {
                CornerBracket(location: .topLeft)
                CornerBracket(location: .topRight)
                CornerBracket(location: .bottomLeft)
                CornerBracket(location: .bottomRight)
            }
            .frame(width: 900, height: 900)
            .foregroundColor(Theme.matrixGreen.opacity(0.4))
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 220)) // iOS App Icon Corner Radius
    }
}

struct CornerBracket: View {
    enum Location { case topLeft, topRight, bottomLeft, bottomRight }
    let location: Location

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let size: CGFloat = 100
                switch location {
                case .topLeft:
                    path.move(to: CGPoint(x: 0, y: size))
                    path.addLine(to: .zero)
                    path.addLine(to: CGPoint(x: size, y: 0))
                case .topRight:
                    path.move(to: CGPoint(x: geo.size.width - size, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: size))
                case .bottomLeft:
                    path.move(to: CGPoint(x: 0, y: geo.size.height - size))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.addLine(to: CGPoint(x: size, y: geo.size.height))
                case .bottomRight:
                    path.move(to: CGPoint(x: geo.size.width - size, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - size))
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .square))
        }
    }
}

#Preview {
    AppIconView()
        .scaleEffect(0.3)
}
