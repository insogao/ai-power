import AIPowerCore
import AppKit
import SwiftUI

@main
struct AI_PowerApp: App {
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let model = AppModel.live()
        _model = StateObject(wrappedValue: model)
        MenuBarAppDelegate.bootstrapModel = model
        NSApplication.shared.setActivationPolicy(.accessory)
        model.startMonitoring()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
