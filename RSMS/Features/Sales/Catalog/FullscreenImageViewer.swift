//
//  FullscreenImageViewer.swift
//  RSMS
//
//  Full-screen swipeable image gallery with pinch-to-zoom.
//  Presented as a sheet when the user taps the product image carousel.
//

import SwiftUI

struct FullscreenImageViewer: View {
    let urls: [URL]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0

    init(urls: [URL], startIndex: Int) {
        self.urls = urls
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image pager
            TabView(selection: $currentIndex) {
                ForEach(urls.indices, id: \.self) { idx in
                    AsyncImage(url: urls[idx]) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(idx == currentIndex ? scale * magnifyBy : 1)
                                .offset(idx == currentIndex ? offset : .zero)
                                .gesture(
                                    MagnificationGesture()
                                        .updating($magnifyBy) { val, state, _ in state = val }
                                        .onEnded { val in
                                            scale = max(1, scale * val)
                                            if scale <= 1 { scale = 1; offset = .zero }
                                        }
                                )
                                .gesture(
                                    scale > 1 ? DragGesture()
                                        .onChanged { offset = $0.translation }
                                        .onEnded { _ in } : nil
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring()) {
                                        scale = scale > 1 ? 1 : 2.5
                                        if scale == 1 { offset = .zero }
                                    }
                                }
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "photo.slash")
                                    .font(.system(size: 48, weight: .ultraLight))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("Image unavailable")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, _ in
                scale = 1; offset = .zero
            }

            // Top bar
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    if urls.count > 1 {
                        Text("\(currentIndex + 1) / \(urls.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                Spacer()

                // Page dots
                if urls.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(urls.indices, id: \.self) { idx in
                            Circle()
                                .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: idx == currentIndex ? 8 : 5,
                                       height: idx == currentIndex ? 8 : 5)
                                .animation(.easeInOut(duration: 0.15), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .statusBarHidden(true)
    }
}
