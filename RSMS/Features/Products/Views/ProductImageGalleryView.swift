//
//  ProductImageGalleryView.swift
//  RSMS
//
//  Fullscreen immersive image gallery with swipe, pinch-to-zoom, and page counter.
//

import SwiftUI

struct ProductImageGalleryView: View {
    let images: [String]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showChrome = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Main pager
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { idx in
                    ZoomableImageCell(imageSource: images[idx])
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Chrome overlay (toggle on tap)
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    // Image counter pill
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Bottom dot indicator
                HStack(spacing: 8) {
                    ForEach(images.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(
                                width: idx == currentIndex ? 8 : 5,
                                height: idx == currentIndex ? 8 : 5
                            )
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
                .padding(.vertical, 20)
            }
            .opacity(showChrome ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showChrome)
        }
        .onTapGesture {
            withAnimation { showChrome.toggle() }
        }
        .statusBarHidden(true)
    }
}

// MARK: - Zoomable image cell

private struct ZoomableImageCell: View {
    let imageSource: String
    @State private var scale:      CGFloat  = 1.0
    @State private var lastScale:  CGFloat  = 1.0
    @State private var offset:     CGSize   = .zero
    @State private var lastOffset: CGSize   = .zero

    var body: some View {
        ZStack {
            Color.black

            if let url = ProductImageResolver.url(from: imageSource) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(dragGesture)
                            .gesture(magnificationGesture)
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.35)) {
                                    scale = scale > 1 ? 1.0 : 2.2
                                    offset = .zero
                                }
                            }
                    case .empty:
                        ProgressView().tint(AppColors.accent)
                    case .failure:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .ignoresSafeArea()
    }

    private var fallbackIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 64))
            .foregroundColor(.white.opacity(0.3))
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1.0), 5.0)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.0 {
                    withAnimation(.spring()) { scale = 1.0; offset = .zero }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in lastOffset = offset }
    }
}
