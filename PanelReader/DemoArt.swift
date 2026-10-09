import SwiftUI

struct DemoCover: View {
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 180, geometry.size.height / 264)
            ZStack {
                LinearGradient(colors: [Color(red: 0.12, green: 0.21, blue: 0.27), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 12 * scale) {
                    Text("PANEL ORIGINAL").font(.system(size: 9 * scale, weight: .bold, design: .monospaced))
                        .tracking(2 * scale).foregroundStyle(.mint)
                    Spacer(minLength: 0)
                    Image(systemName: "tram.fill").font(.system(size: 50 * scale)).foregroundStyle(.mint)
                    Text("NIGHT\nTRAIN").font(.system(size: 29 * scale, weight: .black, design: .rounded))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(-3 * scale).foregroundStyle(.white)
                    Rectangle().fill(.mint).frame(height: 3 * scale)
                    Text("A SIX-PAGE SAMPLE").font(.system(size: 8 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                }.padding(20 * scale)
            }
        }
    }
}

struct DemoPage: View {
    let index: Int
    private let captions = [
        "The last train arrived without a sound.",
        "Inside, every window showed a different city.",
        "A small light waited on the empty seat.",
        "I picked it up. The whole carriage glowed.",
        "Outside, the sleeping city began to wake.",
        "Some journeys begin with a single page."
    ]
    private let symbols = ["tram.fill", "building.2.fill", "sparkle", "lightbulb.fill", "sunrise.fill", "book.fill"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NIGHT TRAIN").font(.caption.weight(.black)).tracking(2)
                Spacer()
                Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
            }.padding(22)
            ZStack {
                LinearGradient(colors: [.indigo.opacity(0.75), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 26) {
                    Image(systemName: symbols[index]).font(.system(size: 88, weight: .light))
                        .foregroundStyle(.mint)
                    HStack(spacing: 14) {
                        ForEach(0..<5, id: \.self) { position in
                            RoundedRectangle(cornerRadius: 3).fill(.mint.opacity(Double(position + 1) / 8))
                                .frame(width: 24, height: CGFloat(28 + position * 12))
                        }
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 4)).padding(.horizontal, 18)
            Text(captions[index]).font(.title3.weight(.medium))
                .multilineTextAlignment(.center).padding(28)
            Text(index == 5 ? "END OF SAMPLE" : "Swipe or scroll to continue")
                .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 20)
        }
        .foregroundStyle(.white)
        .background(Color(white: 0.12))
        .aspectRatio(1 / 1.45, contentMode: .fit)
        .accessibilityElement(children: .combine)
    }
}
