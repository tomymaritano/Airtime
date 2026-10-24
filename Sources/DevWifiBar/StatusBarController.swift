import AppKit
import Combine
import DevWifiCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let state: AppState
    private let layout: WidgetLayoutStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    init(state: AppState, layout: WidgetLayoutStore) {
        self.state = state
        self.layout = layout
        self.statusItem = NSStatusBar.system.statusItem(withLength: 24)
        self.popover = NSPopover()
        super.init()
        configurePopover()
        configureStatusItem()
        observeSnapshot()
    }

    private func configurePopover() {
        let host = NSHostingController(rootView: MenuPanelView().environmentObject(state).environmentObject(layout))
        host.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
    }

    private func configureStatusItem() {
        statusItem.isVisible = true
        guard let button = statusItem.button else { return }
        button.image = BrandMark.menuBarImage(for: state.snapshot)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = ProductName.display
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
    }

    private func observeSnapshot() {
        Publishers.CombineLatest(state.$snapshot, state.$aiTraffic)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot, traffic in
                guard let button = self?.statusItem.button else { return }
                button.image = BrandMark.menuBarImage(for: snapshot)
                button.toolTip = traffic.activeCount > 0
                    ? "\(ProductName.display) · \(traffic.activeCount) AI on link"
                    : ProductName.display
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
