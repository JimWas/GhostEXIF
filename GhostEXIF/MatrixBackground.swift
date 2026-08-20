import SwiftUI

struct MatrixBackground: View {
    let characters = "01ABCDEFGHIJKLMNOPQRSTUVWXYZｦｱｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ"

    var body: some View {
        ZStack {
            Color.black
            GeometryReader { geo in
                let columns = Int(geo.size.width / 20)
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { _ in
                        MatrixColumn(characters: characters, screenHeight: geo.size.height)
                    }
                }
            }
            ScanlineOverlay()
        }
        .ignoresSafeArea()
    }
}

struct MatrixColumn: View {
    let characters: String
    let screenHeight: CGFloat
    @State private var text: String = ""
    @State private var offset: CGFloat = 0

    var body: some View {
        let characters = Array(text)
        VStack(spacing: 0) {
            ForEach(characters.indices, id: \.self) { index in
                Text(String(characters[index]))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.matrixGreen.opacity(0.15))
            }
        }
        .frame(width: 20)
        .offset(y: offset)
        .onAppear {
            generateText()
            offset = -screenHeight
            withAnimation(Animation.linear(duration: Double.random(in: 10...30)).repeatForever(autoreverses: false)) {
                offset = screenHeight
            }
        }
    }

    private func generateText() {
        var newText = ""
        let length = Int(screenHeight / 12)
        for _ in 0..<length {
            newText.append(characters.randomElement()!)
        }
        text = newText
    }
}
