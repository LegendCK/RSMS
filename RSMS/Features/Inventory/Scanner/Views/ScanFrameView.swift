//
//  ScanFrameView.swift
//  RSMS
//
//  Premium SwiftUI scanner frame overlay with:
//  - 4-strip dark vignette focusing attention on the scan area
//  - Corner bracket brackets (accent colored, rounded caps)
//  - Animated horizontal scan line moving up/down inside the frame
//  - Subtle glowing border when session is active
//

import SwiftUI

// MARK: - Frame Geometry

struct ScanFrameGeometry {
    let inset: CGFloat = 36
    let cornerRadius: CGFloat = 18
    let cornerLength: CGFloat = 28
    let cornerLineWidth: CGFloat = 3.5

    var frameRect: CGRect {
        let screenW = UIScreen.main.bounds.width
        let width   = screenW - inset * 2
        let height  = width * 0.62
        let screenH = UIScreen.main.bounds.height
        let y       = screenH * 0.5 - height * 0.5 - 30  // slightly above center
        return CGRect(x: inset, y: y, width: width, height: height)
    }
}

// MARK: - ScanFrameView

struct ScanFrameView: View {
    var sessionActive: Bool
    @State private var scanLineOffset: CGFloat = 0
    @State private var glowPulse: Bool = false

    private let geo = ScanFrameGeometry()

    var body: some View {
        GeometryReader { proxy in
            let rect = frameRect(in: proxy)

            ZStack {
                // 1. Dark vignette strips (4-sided cutout approach)
                vignetteOverlay(in: proxy, frameRect: rect)

                // 2. Corner brackets
                cornerBrackets(rect: rect)

                // 3. Animated scan line (only when session active)
                if sessionActive {
                    scanLine(rect: rect)
                }

                // 4. Glow border (session active pulse)
                if sessionActive {
                    RoundedRectangle(cornerRadius: geo.cornerRadius)
                        .stroke(
                            AppColors.accent.opacity(glowPulse ? 0.55 : 0.15),
                            lineWidth: 1.5
                        )
                        .blur(radius: glowPulse ? 6 : 3)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: glowPulse
                        )
                }
            }
            .onAppear {
                startScanLine(rect: rect)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    glowPulse = true
                }
            }
            .onChange(of: sessionActive) { _, active in
                if active { startScanLine(rect: rect) }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Frame Rect

    private func frameRect(in proxy: GeometryProxy) -> CGRect {
        let w = proxy.size.width - geo.inset * 2
        let h = w * 0.62
        let x = geo.inset
        let y = proxy.size.height * 0.5 - h * 0.5 - 30
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Vignette (4 strips around the frame)

    private func vignetteOverlay(in proxy: GeometryProxy, frameRect: CGRect) -> some View {
        let totalW = proxy.size.width
        let totalH = proxy.size.height
        let r = frameRect

        return ZStack {
            // Top strip
            Rectangle()
                .fill(Color.black.opacity(0.72))
                .frame(width: totalW, height: r.minY)
                .position(x: totalW / 2, y: r.minY / 2)

            // Bottom strip
            Rectangle()
                .fill(Color.black.opacity(0.72))
                .frame(width: totalW, height: totalH - r.maxY)
                .position(x: totalW / 2, y: r.maxY + (totalH - r.maxY) / 2)

            // Left strip
            Rectangle()
                .fill(Color.black.opacity(0.72))
                .frame(width: r.minX, height: r.height)
                .position(x: r.minX / 2, y: r.midY)

            // Right strip
            Rectangle()
                .fill(Color.black.opacity(0.72))
                .frame(width: totalW - r.maxX, height: r.height)
                .position(x: r.maxX + (totalW - r.maxX) / 2, y: r.midY)
        }
    }

    // MARK: - Corner Brackets

    private func cornerBrackets(rect: CGRect) -> some View {
        Canvas { ctx, _ in
            let r   = rect
            let c   = geo.cornerLength
            let lw  = geo.cornerLineWidth
            let cr  = geo.cornerRadius

            var path = Path()

            // Top-left
            path.move(to: CGPoint(x: r.minX + cr, y: r.minY + c))
            path.addLine(to: CGPoint(x: r.minX + cr, y: r.minY + cr))
            path.addQuadCurve(
                to: CGPoint(x: r.minX + cr + cr * 0.3, y: r.minY),
                control: CGPoint(x: r.minX + cr, y: r.minY)
            )
            path.addLine(to: CGPoint(x: r.minX + c + cr, y: r.minY))

            // Top-right
            path.move(to: CGPoint(x: r.maxX - c - cr, y: r.minY))
            path.addLine(to: CGPoint(x: r.maxX - cr - cr * 0.3, y: r.minY))
            path.addQuadCurve(
                to: CGPoint(x: r.maxX - cr, y: r.minY + cr),
                control: CGPoint(x: r.maxX - cr, y: r.minY)
            )
            path.addLine(to: CGPoint(x: r.maxX - cr, y: r.minY + c))

            // Bottom-right
            path.move(to: CGPoint(x: r.maxX - cr, y: r.maxY - c))
            path.addLine(to: CGPoint(x: r.maxX - cr, y: r.maxY - cr))
            path.addQuadCurve(
                to: CGPoint(x: r.maxX - cr - cr * 0.3, y: r.maxY),
                control: CGPoint(x: r.maxX - cr, y: r.maxY)
            )
            path.addLine(to: CGPoint(x: r.maxX - c - cr, y: r.maxY))

            // Bottom-left
            path.move(to: CGPoint(x: r.minX + c + cr, y: r.maxY))
            path.addLine(to: CGPoint(x: r.minX + cr + cr * 0.3, y: r.maxY))
            path.addQuadCurve(
                to: CGPoint(x: r.minX + cr, y: r.maxY - cr),
                control: CGPoint(x: r.minX + cr, y: r.maxY)
            )
            path.addLine(to: CGPoint(x: r.minX + cr, y: r.maxY - c))

            ctx.stroke(
                path,
                with: .color(AppColors.accent),
                style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - Animated Scan Line

    private func scanLine(rect: CGRect) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, AppColors.accent.opacity(0.9), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: rect.width - 4, height: 2)
            .blur(radius: 1.5)
            .position(x: rect.midX, y: rect.minY + scanLineOffset)
            .clipped()
    }

    private func startScanLine(rect: CGRect) {
        scanLineOffset = 8
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            scanLineOffset = rect.height - 8
        }
    }
}
