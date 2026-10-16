import AppKit
import SwiftUI

final class GardenModel: ObservableObject {
    @Published var recent: [ClipRecord] = []
    @Published var frequent: [ClipRecord] = []
    @Published var search = "" { didSet { visibleLimit = 60; refresh() } }
    @Published var total = 0
    @Published var diskBytes: Int64 = 0
    @Published var enabled = false
    @Published var consented = false
    @Published var showSettings = false
    @Published var showClear = false
    @Published var preview: ClipRecord?
    @Published var toast: String?
    @Published var error: String?
    @Published var shortcut = Shortcut.standard
    @Published var shortcutMessage: String?
    @Published var recording = false
    private(set) var visibleLimit = 60
    let store: HistoryStore
    let demo: Bool
    let pasteboard: NSPasteboard
    let reader = ClipboardReader()
    let hotKey = GlobalHotKey()
    private let defaults: UserDefaults
    private var timer: Timer?
    private var toastToken = UUID()
    var onShow: (() -> Void)?
    init(store: HistoryStore, demo: Bool = false, preferences: UserDefaults? = nil) {
        self.store = store; self.demo = demo
        defaults = preferences ?? (demo ? UserDefaults(suiteName: "local.clipgarden.demo.\(UUID().uuidString)")! : UserDefaults.standard)
        pasteboard = demo ? NSPasteboard.withUniqueName() : .general
        consented = demo || defaults.bool(forKey: "consented")
        enabled = !demo && consented && defaults.bool(forKey: "captureEnabled")
        if let data = defaults.data(forKey: "shortcut"), let saved = try? JSONDecoder().decode(Shortcut.self, from: data) { shortcut = saved }
        refresh()
        hotKey.onPress = { [weak self] in self?.onShow?() }
        if !demo {
            shortcutMessage = hotKey.register(shortcut)
            if enabled { startTimer() }
        }
    }
    deinit { timer?.invalidate(); if demo { pasteboard.releaseGlobally() } }
    func accept() {
        consented = true; defaults.set(true, forKey: "consented"); setEnabled(true)
    }
    func setEnabled(_ value: Bool) {
        guard consented else { return }
        enabled = value; defaults.set(value, forKey: "captureEnabled")
        timer?.invalidate(); timer = nil
        if value && !demo { startTimer() }
    }
    private func startTimer() {
        // Only the change counter is inspected here; the pre-existing clipboard is never imported.
        reader.baseline(pasteboard)
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in self?.poll() }
    }
    func poll() {
        guard enabled, consented else { return }
        guard let value = reader.readChange(pasteboard) else { return }
        do { try store.ingest(value); refresh() } catch { self.error = "保存失败，已暂停记录：\(error.localizedDescription)"; setEnabled(false) }
    }
    func refresh() {
        do {
            recent = try store.fetch(order: .recent, search: search, limit: visibleLimit)
            frequent = try store.fetch(order: .frequent, search: search, limit: visibleLimit)
            total = try store.count(); diskBytes = store.diskBytes
        } catch { self.error = "无法读取本地历史：\(error.localizedDescription)" }
    }
    func loadMore() { visibleLimit += 60; refresh() }
    func copy(_ record: ClipRecord) {
        do {
            guard let payload = try store.payload(id: record.id) else { return }
            guard reader.write(payload, to: pasteboard) else { error = "复制失败，请重试。"; return }
            notify(demo ? "演示复制成功 · 使用隔离测试剪贴板" : "已复制，去粘贴吧！")
        } catch { self.error = error.localizedDescription }
    }
    func delete(_ record: ClipRecord) {
        do { try store.delete(id: record.id); if preview?.id == record.id { preview = nil }; refresh(); notify("这条记忆已删除") } catch { self.error = error.localizedDescription }
    }
    func clear() {
        do { try store.clear(); preview = nil; refresh(); notify("历史已清空") } catch { self.error = error.localizedDescription }
    }
    func saveShortcut(_ value: Shortcut) {
        if let failure = hotKey.register(value) { shortcutMessage = failure; return }
        shortcut = value; defaults.set(try? JSONEncoder().encode(value), forKey: "shortcut"); shortcutMessage = "已保存，可以在其他应用中试试。"
    }
    func notify(_ message: String) {
        let token = UUID(); toastToken = token; toast = message
        DispatchQueue.main.asyncAfter(deadline: .now()+2.5) { [weak self] in if self?.toastToken == token { self?.toast = nil } }
    }
    static func makeDemo(store: HistoryStore) throws {
        let samples: [(String, Int, Double)] = [
            ("周末的小计划 🌿\n去公园晒太阳，带上相机和一杯冰拿铁。", 3, 10),
            ("把灵感收进口袋 ✨\n今天也要做一点让自己开心的小事。", 12, 100),
            ("你好，世界！\nHello, little world.", 24, 260),
            ("https://example.com/my-little-garden", 8, 400),
            ("会议备忘（演示）\n① 画出第一版草图\n② 试试奶油色和薄荷绿\n③ 下周一起看成果", 5, 650),
            ("常用地址（虚构）\n月亮市 云朵街 42 号", 18, 1200),
            ("let happiness = ideas + coffee ☕️", 7, 1800),
            ("两年前的灵感也在这里\n历史不会按时间自动过期。", 2, 730*86400)
        ]
        for (text, count, age) in samples {
            for _ in 0..<count { try store.ingest(.text(text), at: Date().addingTimeInterval(-age)) }
        }
        let art = NSImage(size: NSSize(width: 600, height: 360))
        art.lockFocus()
        NSColor(calibratedRed: 0.77, green: 0.88, blue: 0.82, alpha: 1).setFill(); NSRect(x: 0,y: 0,width: 600,height: 360).fill()
        NSColor(calibratedRed: 1, green: 0.84, blue: 0.43, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 390,y: 200,width: 100,height: 100)).fill()
        NSColor(calibratedRed: 0.37,green: 0.64,blue: 0.51,alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: -80,y: -120,width: 480,height: 340)).fill()
        NSColor(calibratedRed: 0.22,green: 0.47,blue: 0.38,alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 210,y: -130,width: 520,height: 320)).fill()
        ("小小风景 · 合成图" as NSString).draw(at: NSPoint(x: 35,y: 280), withAttributes: [.font: NSFont.systemFont(ofSize: 24,weight: .bold), .foregroundColor: NSColor(calibratedWhite: 0.18,alpha: 1)])
        art.unlockFocus()
        if let payload = ClipPayload.image(art) { try store.ingest(payload, at: Date().addingTimeInterval(-50)) }
    }
}
