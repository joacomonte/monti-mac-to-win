import AppKit
import SwiftUI

@main
struct LanDropMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSDraggingDestination {
    let store = Store()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let button = statusItem.button!
        button.image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: "Monti Mac2Win")
        button.target = self
        button.action = #selector(toggle)

        // Permite soltar archivos directo sobre el ícono del menubar.
        button.window?.registerForDraggedTypes([.fileURL])
        button.window?.delegate = self

        let host = NSHostingController(rootView: ContentView(store: store, state: ViewState()))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        // No se cierra al hacer click afuera: así se puede arrastrar desde Finder.
        popover.behavior = .applicationDefined
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.cleanup()
    }

    @objc private func toggle() {
        popover.isShown ? popover.performClose(nil) : show()
    }

    private func show() {
        store.objectWillChange.send() // refresca la IP por si cambió de red
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        store.addFiles(urls)
        if !popover.isShown { show() }
        return !urls.isEmpty
    }
}
