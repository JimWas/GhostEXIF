import SwiftUI

enum Theme {
    static let background = Color.black
    static let matrixGreen = Color(red: 0.0, green: 1.0, blue: 0.2)
    static let terminalCyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    static let alertAmber = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let errorRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    static let threatLow = Color.green
    static let threatMedium = Color.yellow
    static let threatHigh = Color.red

    static func nasalizationFont(size: CGFloat) -> Font {
        return Font.custom("Nasalization", size: size)
    }

    static func terminalFont(size: CGFloat) -> Font {
        return Font.system(size: size, weight: .regular, design: .monospaced)
    }
}

struct HackerPanel: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.black.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                // Corner accents
                ZStack {
                    CornerAccent(location: .topLeft, color: color)
                    CornerAccent(location: .topRight, color: color)
                    CornerAccent(location: .bottomLeft, color: color)
                    CornerAccent(location: .bottomRight, color: color)
                }
            )
    }
}

struct CornerAccent: View {
    enum Location { case topLeft, topRight, bottomLeft, bottomRight }
    let location: Location
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let size: CGFloat = 10
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
            .stroke(color, lineWidth: 2)
        }
    }
}

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                ForEach(0..<Int(geo.size.height / 4), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func hackerPanel(color: Color = Theme.matrixGreen) -> some View {
        self.modifier(HackerPanel(color: color))
    }

    func matrixText(size: CGFloat = 16, color: Color = Theme.matrixGreen, isHeader: Bool = false) -> some View {
        self.font(isHeader ? Theme.nasalizationFont(size: size) : Theme.terminalFont(size: size))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.5), radius: isHeader ? 4 : 0)
    }
}

enum Haptics {
    static func play(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
