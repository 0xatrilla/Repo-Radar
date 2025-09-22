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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Repo Radar Pro")
                            .font(.title2).bold()
                        Spacer()
                    }

                    Text("Support development and unlock premium features. I'm just one developer building Repo Radar — your subscription helps me keep improving it.")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Track unlimited repositories", systemImage: "infinity")
                        Label("Exclusive color & gradient themes", systemImage: "paintpalette")
                        Label("Smart notifications (releases, stars, issues)", systemImage: "bell")
                        Label("Faster refresh & priority features", systemImage: "bolt")
                    }
                    .font(.body)

                    // Subscription Information (Required by App Store)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subscription Details")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Title: Repo Radar Pro")
                            Text("• Duration: Monthly subscription")
                            Text("• Price: $2.99 per month")
                            Text("• Content: Unlimited repository tracking, premium themes, advanced notifications")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        if pro.isSubscribed {
                            Text("You're Pro! Thank you ✨")
                                .foregroundColor(.green)
                            Spacer()
                            Button("Close") { NSApplication.shared.keyWindow?.close() }
                        } else {
                            Button(pro.isPurchasing ? "Purchasing…" : "Get Pro - $2.99/month") {
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
                    
                    // Legal Links (Required by App Store)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Legal")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Button("Terms of Use (EULA)") {
                                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            
                            Button("Privacy Policy") {
                                if let url = URL(string: "https://github.com/0xatrilla/Repo-Radar/blob/main/PRIVACY_POLICY.md") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                        }
                        .font(.caption)
                    }
                }
                .padding()
            }

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
                        let rect = CGRect(x: particles[i].x, y: particles[i].y, width: 6, height: 8)
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


