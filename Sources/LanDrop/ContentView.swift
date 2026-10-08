import AppKit
import SwiftUI

/// Estado efímero de la UI. Se usa ObservableObject y no @State porque en el SDK de
/// macOS 27 @State es una macro cuyo plugin solo viene con Xcode (no con las CLT).
final class ViewState: ObservableObject {
    @Published var text = ""
    @Published var isTargeted = false
    @Published var copied = false
    @Published var hoveredID: String?
}

struct ContentView: View {
    @ObservedObject var store: Store
    @ObservedObject var state: ViewState

    var body: some View {
        VStack(spacing: 12) {
            header
            dropZone
            textInput
            if !store.items.isEmpty { itemList }
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    // MARK: - Secciones

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .foregroundStyle(.tint)
                Text("Monti Mac2Win").font(.headline)
                Spacer()
                Circle()
                    .fill(store.serverError == nil ? .green : .red)
                    .frame(width: 8, height: 8)
            }

            Button(action: copyURL) {
                HStack {
                    Text(store.url)
                        .font(.system(.callout, design: .monospaced))
                    Spacer()
                    Image(systemName: state.copied ? "checkmark" : "doc.on.doc")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .id("copy-url-button")
            .help("Copiar URL — abrila en el navegador de la otra compu")

            if let error = store.serverError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 24, weight: .light))
            Text("Soltá archivos o carpetas acá")
                .font(.callout)
        }
        .foregroundStyle(state.isTargeted ? Color.accentColor : .secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(state.isTargeted ? Color.accentColor.opacity(0.12) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(state.isTargeted ? Color.accentColor : .secondary.opacity(0.5))
        )
        .animation(.easeOut(duration: 0.15), value: state.isTargeted)
        .dropDestination(for: URL.self) { urls, _ in
            store.addFiles(urls)
            return true
        } isTargeted: { state.isTargeted = $0 }
        .id("drop-zone")
    }

    private var textInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Escribí o pegá un texto…", text: $state.text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .onSubmit(sendText)
                .id("text-input")

            Button(action: sendText) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 24))
            }
            .buttonStyle(.plain)
            .foregroundStyle(state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
            .disabled(state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .id("send-text-button")
        }
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(store.items) { item in
                    ItemRow(item: item, state: state) { store.remove(item) }
                }
            }
        }
        .frame(maxHeight: 220)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Button("Limpiar todo") { store.clear() }
                .disabled(store.items.isEmpty)
                .id("clear-button")
            Spacer()
            Button("Salir") { NSApp.terminate(nil) }
                .id("quit-button")
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    // MARK: - Acciones

    private func sendText() {
        store.addText(state.text)
        state.text = ""
    }

    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(store.url, forType: .string)
        state.copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [state] in state.copied = false }
    }
}

private struct ItemRow: View {
    let item: SharedItem
    @ObservedObject var state: ViewState
    let onRemove: () -> Void

    private var hovering: Bool { state.hoveredID == item.id }

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .id("remove-\(item.id)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        .onHover { inside in
            if inside { state.hoveredID = item.id } else if hovering { state.hoveredID = nil }
        }
    }

    @ViewBuilder private var icon: some View {
        switch item.kind {
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 16))
                .foregroundStyle(.tint)
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .file: ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
        case .text: "Texto · \(item.size) bytes"
        }
    }
}
