import AppKit
import Combine
import SwiftUI

enum MenuBarActivationBehavior {
    static let togglePopoverMask: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp]
}

enum MenuBarBadgeStyle: Equatable {
    case standard
}

enum MenuBarIconGlyph: Equatable {
    case waveformIdle
    case waveformActive
    case infinity
    case orbitX
}

struct MenuBarIconDescriptor: Equatable {
    let glyph: MenuBarIconGlyph
    let badgeStyle: MenuBarBadgeStyle

    static let badgeRect = NSRect(x: 0.3, y: 0.3, width: 17.4, height: 17.4)

    static func waveformGlyphRect(for glyph: MenuBarIconGlyph) -> NSRect {
        switch glyph {
        case .waveformIdle:
            return NSRect(x: 2.0, y: 2.9, width: 13.8, height: 11.1)
        case .waveformActive:
            return NSRect(x: 1.9, y: 2.8, width: 14.1, height: 11.5)
        case .infinity:
            return NSRect(x: 2.4, y: 2.7, width: 13.0, height: 12.0)
        case .orbitX:
            return NSRect(x: 2.2, y: 2.2, width: 13.4, height: 13.4)
        }
    }

    var symbolName: String {
        switch glyph {
        case .waveformIdle, .waveformActive, .infinity:
            return ""
        case .orbitX:
            return ""
        }
    }

    static func descriptor(for state: MenuBarIconState) -> MenuBarIconDescriptor {
        switch state {
        case .off:
            return MenuBarIconDescriptor(
                glyph: .waveformIdle,
                badgeStyle: .standard
            )
        case .armed:
            return MenuBarIconDescriptor(
                glyph: .waveformActive,
                badgeStyle: .standard
            )
        case .infinity:
            return MenuBarIconDescriptor(
                glyph: .infinity,
                badgeStyle: .standard
            )
        case .warning:
            return MenuBarIconDescriptor(
                glyph: .orbitX,
                badgeStyle: .standard
            )
        }
    }

    func makeImage() -> NSImage? {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let badgeRect = Self.badgeRect
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 6.7, yRadius: 6.7)
        let backgroundColors = self.backgroundColors
        if let gradient = NSGradient(colors: backgroundColors) {
            gradient.draw(in: badgePath, angle: 90)
        } else {
            backgroundColors[0].setFill()
            badgePath.fill()
        }
        borderColor.setStroke()
        badgePath.lineWidth = 1
        badgePath.stroke()

        switch glyph {
        case .waveformIdle:
            WaveformBadgeArtwork.drawGlyph(
                in: Self.waveformGlyphRect(for: glyph),
                style: .idle
            )
        case .waveformActive:
            WaveformBadgeArtwork.drawGlyph(
                in: Self.waveformGlyphRect(for: glyph),
                style: .active
            )
        case .infinity:
            drawInfinityGlyph(
                in: Self.waveformGlyphRect(for: glyph),
                color: foregroundColor
            )
        case .orbitX:
            WarningOrbitArtwork.drawGlyph(
                in: Self.waveformGlyphRect(for: glyph),
                primary: foregroundColor,
                secondary: borderColor,
                center: foregroundColor
            )
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private var backgroundColors: [NSColor] {
        switch badgeStyle {
        case .standard:
            return [
                NSColor(calibratedRed: 0.18, green: 0.25, blue: 0.31, alpha: 1),
                NSColor(calibratedRed: 0.10, green: 0.15, blue: 0.20, alpha: 1),
            ]
        }
    }

    private var foregroundColor: NSColor {
        switch glyph {
        case .waveformIdle:
            return NSColor(calibratedRed: 0.52, green: 0.93, blue: 0.86, alpha: 1)
        case .waveformActive, .infinity:
            return NSColor(calibratedRed: 0.16, green: 0.90, blue: 0.80, alpha: 1)
        case .orbitX:
            return NSColor(calibratedRed: 0.71, green: 0.31, blue: 0.05, alpha: 1)
        }
    }

    private var borderColor: NSColor {
        switch badgeStyle {
        case .standard:
            return NSColor(calibratedRed: 0.46, green: 0.57, blue: 0.66, alpha: 1)
        }
    }

    private func drawInfinityGlyph(in rect: NSRect, color: NSColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.8, weight: .semibold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]

        let text = NSAttributedString(string: "∞", attributes: attributes)
        let textSize = text.size()
        let drawRect = NSRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2 - 0.5,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: drawRect)
    }
}

@MainActor
final class MenuBarStatusController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let hostingController: NSHostingController<MenuBarView>
    private var cancellables = Set<AnyCancellable>()
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var lastHandledOnboardingToken: UUID?

    init(model: AppModel, statusBar: NSStatusBar = .system) {
        self.model = model
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.hostingController = NSHostingController(rootView: MenuBarView(model: model))
        super.init()
        configurePopover()
        configureStatusItem()
        bindModel()
        applyIcon(for: model.menuBarIconState)
        if let onboardingToken = model.onboardingAutoOpenToken {
            handleOnboardingAutoOpen(onboardingToken)
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: 344, height: 320)
        popover.contentViewController = hostingController
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        statusItem.length = 28
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: MenuBarActivationBehavior.togglePopoverMask)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func bindModel() {
        model.$menuBarIconState
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.applyIcon(for: state)
            }
            .store(in: &cancellables)

        model.$onboardingAutoOpenToken
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] token in
                self?.handleOnboardingAutoOpen(token)
            }
            .store(in: &cancellables)
    }

    private func applyIcon(for state: MenuBarIconState) {
        guard let button = statusItem.button else {
            return
        }

        let descriptor = MenuBarIconDescriptor.descriptor(for: state)
        button.image = descriptor.makeImage()
        button.contentTintColor = nil
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.appearsDisabled = false
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(activateApp: true)
        }
    }

    private func showPopover(activateApp: Bool) {
        guard let button = statusItem.button else {
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startEventMonitoring()
        if activateApp {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        stopEventMonitoring()
    }

    private func handleOnboardingAutoOpen(_ token: UUID) {
        guard token != lastHandledOnboardingToken else {
            return
        }

        lastHandledOnboardingToken = token
        guard popover.isShown == false else {
            return
        }

        showPopover(activateApp: true)
    }

    private func startEventMonitoring() {
        guard globalEventMonitor == nil, localEventMonitor == nil else {
            return
        }

        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.closePopover(nil)
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            guard let self else {
                return event
            }

            if event.type == .keyDown, event.keyCode == 53 { // ESC
                self.closePopover(nil)
                return nil
            }

            guard event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown else {
                return event
            }

            let popoverWindow = self.popover.contentViewController?.view.window
            if event.window != popoverWindow {
                self.closePopover(nil)
            }

            return event
        }
    }

    private func stopEventMonitoring() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

}

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    static var bootstrapModel: AppModel?

    private var statusController: MenuBarStatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let model = Self.bootstrapModel else {
            return
        }

        statusController = MenuBarStatusController(model: model)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = Self.bootstrapModel else {
            return .terminateNow
        }

        Task { @MainActor in
            await model.prepareForTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.bootstrapModel?.stopMonitoring()
    }
}
