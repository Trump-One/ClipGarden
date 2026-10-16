import AppKit
import SwiftUI

@main
struct ClipGardenMain {
    static func main() {
        let app = NSApplication.shared
        if CommandLine.arguments.contains("--self-test") {
            do { try SyntheticTests.run(); exit(0) } catch { fputs("FAIL: \(error)\n",stderr); exit(1) }
        }
        let delegate = GardenDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class GardenDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var model: GardenModel!
    var statusItem: NSStatusItem!
    var screenshotMode = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        screenshotMode = arguments.contains("--screenshot")
        let demo = arguments.contains("--demo") || screenshotMode
        do {
            let root = demo ? FileManager.default.temporaryDirectory.appendingPathComponent("ClipGarden-Demo-\(UUID().uuidString)",isDirectory: true) : try FileManager.default.url(for: .applicationSupportDirectory,in: .userDomainMask,appropriateFor: nil,create: true).appendingPathComponent("ClipGarden",isDirectory: true)
            let store = try HistoryStore(url: root.appendingPathComponent("history.sqlite3"))
            if demo { try GardenModel.makeDemo(store: store) }
            model = GardenModel(store: store,demo: demo)
            if arguments.contains("--consent-preview") { model.consented = false }
            window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 1060,height: 790),styleMask: [.titled,.closable,.miniaturizable,.resizable],backing: .buffered,defer: false)
            window.title = "剪贴花园"
            window.minSize = NSSize(width: 890,height: 710)
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(calibratedRed: 0.98,green: 0.96,blue: 0.90,alpha: 1)
            window.delegate = self
            let view: AnyView
            if arguments.contains("--settings-preview") { view = AnyView(SettingsView(model: model)) }
            else if arguments.contains("--detail-preview"), let record = model.recent.first { view = AnyView(PreviewView(model: model,record: record)) }
            else { view = AnyView(MainView(model: model)) }
            let host = NSHostingView(rootView: view.environment(\.colorScheme,.light).environment(\.locale, Locale(identifier: "zh_Hans_CN")))
            window.contentView = host
            if arguments.contains("--settings-preview") { window.setContentSize(NSSize(width: 646,height: 660)) }
            if arguments.contains("--detail-preview") { window.setContentSize(NSSize(width: 680,height: 560)) }
            window.center()
            model.onShow = { [weak self] in self?.showWindow() }
            if !screenshotMode { createMenu() }
            showWindow()
            if screenshotMode, let index = arguments.firstIndex(of: "--screenshot"), arguments.count > index+1 {
                let destination = URL(fileURLWithPath: arguments[index+1])
                DispatchQueue.main.asyncAfter(deadline: .now()+1.5) {
                    do {
                        host.layoutSubtreeIfNeeded()
                        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "Screenshot",code: 1) }
                        host.cacheDisplay(in: host.bounds,to: bitmap)
                        guard let png = bitmap.representation(using: .png,properties: [:]) else { throw NSError(domain: "Screenshot",code: 2) }
                        try png.write(to: destination)
                        print("SYNTHETIC_UI_SCREENSHOT: \(destination.path)")
                        try? FileManager.default.removeItem(at: root)
                        NSApp.terminate(nil)
                    } catch { fputs("Screenshot failed: \(error)\n",stderr); exit(1) }
                }
            }
        } catch {
            let alert = NSAlert(); alert.messageText = "剪贴花园暂时无法打开"; alert.informativeText = "本地数据没有被清空。\n\(error.localizedDescription)"; alert.runModal(); NSApp.terminate(nil)
        }
    }
    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "leaf.fill",accessibilityDescription: "剪贴花园")
        let menu = NSMenu()
        let show = NSMenuItem(title: "打开剪贴花园",action: #selector(showWindow),keyEquivalent: ""); show.target = self; menu.addItem(show)
        let pause = NSMenuItem(title: "暂停 / 恢复记录",action: #selector(togglePause),keyEquivalent: ""); pause.target = self; menu.addItem(pause)
        let settings = NSMenuItem(title: "设置…",action: #selector(settings),keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出剪贴花园",action: #selector(NSApplication.terminate(_:)),keyEquivalent: "q"); menu.addItem(quit)
        statusItem.menu = menu
        let main = NSMenu()
        let appMenu = NSMenu(); appMenu.addItem(quit.copy() as! NSMenuItem)
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let editMenu = NSMenu(title: "编辑")
        for (title,action,key) in [("剪切",#selector(NSText.cut(_:)),"x"),("复制",#selector(NSText.copy(_:)),"c"),("粘贴",#selector(NSText.paste(_:)),"v"),("全选",#selector(NSText.selectAll(_:)),"a")] { editMenu.addItem(withTitle: title,action: action,keyEquivalent: key) }
        let editItem = NSMenuItem(title: "编辑",action: nil,keyEquivalent: ""); editItem.submenu = editMenu; main.addItem(editItem)
        NSApp.mainMenu = main
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func togglePause() { if !model.consented { showWindow() } else { model.setEnabled(!model.enabled) } }
    @objc func settings() { showWindow(); model.showSettings = true }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
