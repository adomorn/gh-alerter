import AppKit
import SwiftUI
import GHAlerterCore

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(
        inboxStore: InboxStore,
        onCheckNow: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        super.init()

        if let button = statusItem.button {
            if let icon = Self.statusBarIcon() {
                button.image = icon
                button.imagePosition = .imageOnly
            } else {
                button.title = "GH"
            }
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: InboxPopoverView(
                inboxStore: inboxStore,
                onCheckNow: onCheckNow,
                onOpenSettings: onOpenSettings,
                onQuit: onQuit
            )
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private static func statusBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "StatusBarIcon", withExtension: "png") else {
            return nil
        }

        guard let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
