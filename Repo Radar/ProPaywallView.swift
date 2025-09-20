//
//  ProPaywallView.swift
//  Repo Radar
//
import SwiftUI

struct ProPaywallView: View {
    @ObservedObject private var pro = ProManager.shared
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Repo Radar Pro")
                        .font(.title2).bold()
                    Spacer()
                }

                Text("Support development and unlock premium features. I’m just one developer building Repo Radar — your subscription helps me keep improving it.")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Track unlimited repositories", systemImage: "infinity")
                    Label("Exclusive color & gradient themes", systemImage: "paintpalette")
                    Label("Smart notifications (releases, stars, issues)", systemImage: "bell")
                    Label("Faster refresh & priority features", systemImage: "bolt")
                }
                .font(.body)

                Spacer()

                HStack {
                    if pro.isSubscribed {
                        Text("You're Pro! Thank you ✨")
                            .foregroundColor(.green)
                        Spacer()
                        Button("Close") { NSApplication.shared.keyWindow?.close() }
                    } else {
                        Button(pro.isPurchasing ? "Purchasing…" : "Get Pro") {
                            Task {
                                try? await pro.purchasePro()
                                if pro.isSubscribed { withAnimation { showConfetti = true } }
                            }
                        }
                        .keyboardShortcut(.defaultAction)

                        Button("Restore Purchases") {
                            Task { try? await pro.restorePurchases() }
                        }
                    }
                }
            }
            .padding()

            if showConfetti && pro.isSubscribed {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }
}

// Lightweight confetti using particles
struct ConfettiView: View {
    @State private var particles: [Particle] = (0..<120).map { _ in Particle() }
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in particles.indices {
                        particles[i].update(t, bounds: size)
                        var rect = CGRect(x: particles[i].x, y: particles[i].y, width: 6, height: 8)
                        ctx.fill(Path(roundedRect: rect, cornerSize: CGSize(width: 2, height: 2)), with: .color(particles[i].color))
                    }
                }
            }
        }
    }

    struct Particle {
        var x: CGFloat = .random(in: 0...400)
        var y: CGFloat = -.random(in: 0...200)
        var speed: CGFloat = .random(in: 40...140)
        var drift: CGFloat = .random(in: -40...40)
        var hue: Double = .random(in: 0...1)
        var color: Color { Color(hue: hue, saturation: 0.9, brightness: 0.95) }

        mutating func update(_ t: TimeInterval, bounds: CGSize) {
            y += speed * 0.016
            x += drift * 0.016
            if y > bounds.height + 20 { y = -.random(in: 0...100); x = .random(in: 0...bounds.width) }
        }
    }
}


