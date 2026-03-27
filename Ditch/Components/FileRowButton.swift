import SwiftUI
import AppKit

// Click to reveal in Finder, hover shows an arrow
struct FileRowButton: View {
    let file: RelatedFile
    let icon: NSImage
    let path: String
    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(file.url.lastPathComponent)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(isHovered ? 0.95 : 0.75))
                        .lineLimit(1)
                    Text(path)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(isHovered ? 0.5 : 0.3))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                ZStack(alignment: .trailing) {
                    Text(file.formattedSize)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .fixedSize()
                        .opacity(isHovered ? 0 : 1)
                        .offset(x: isHovered ? -8 : 0)

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .opacity(isHovered ? 1 : 0)
                        .offset(x: isHovered ? 0 : 8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(isHovered ? 0.06 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
    }
}

// Each row fades in with a slight delay for that staggered feel
struct StaggeredFileRow: View {
    let content: AnyView
    let index: Int
    @State private var appeared = false

    var body: some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.04)) {
                    appeared = true
                }
            }
    }
}
