import AppKit
import Carbon

struct TestFailure: Error, CustomStringConvertible { let description: String }
enum SyntheticTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () throws -> Bool, _ description: String) throws {
        guard try condition() else { throw TestFailure(description: description) }
        checks += 1; print("PASS: \(description)")
    }
    static func run() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ClipGarden-Test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let dbURL = root.appendingPathComponent("history.sqlite3")
        var store: HistoryStore? = try HistoryStore(url: dbURL)
        let old = Date(timeIntervalSince1970: 1_000_000)
        try store!.ingest(.text("合成 A\n第一行"),at: old)
        try store!.ingest(.text("合成 B 🌱"),at: old.addingTimeInterval(10))
        try store!.ingest(.text("合成 A\n第一行"),at: old.addingTimeInterval(20))
        try check(try store!.count() == 2,"exact content deduplicates")
        let recent = try store!.fetch(order: .recent)
        try check(recent.first?.text == "合成 A\n第一行" && recent.first?.count == 2,"duplicate increments count and reorders recent")
        try check(recent.first?.firstAt == old && recent.first?.lastAt == old.addingTimeInterval(20),"first date preserved, last date updated")
        try store!.ingest(.text("合成 B 🌱"),at: old.addingTimeInterval(30))
        try store!.ingest(.text("合成 B 🌱"),at: old.addingTimeInterval(40))
        try store!.ingest(.text("全新 C"),at: old.addingTimeInterval(50))
        try check(try store!.fetch(order: .recent).first?.text == "全新 C","recent order is descending time")
        try check(try store!.fetch(order: .frequent).first?.text == "合成 B 🌱","frequency order is descending count")
        try check(try store!.fetch(order: .recent,search: "🌱").count == 1,"unicode search")
        try store!.ingest(.text("SELECT ' % _ 数据"))
        try check(try store!.fetch(order: .recent,search: "% _").count == 1,"literal search and SQL binding")
        try store!.ingest(.text(" spaced ")); try store!.ingest(.text("spaced"))
        try check(try store!.count() == 6,"whitespace preserved as different content")
        try check(try store!.fetch(order: .recent,limit: 2,offset: 2).count == 2,"history pagination")
        store = nil; store = try HistoryStore(url: dbURL)
        try check(try store!.count() == 6,"history survives database reopen")
        try check(try store!.fetch(order: .frequent).first?.count == 3,"copy counts survive reopen")
        try store!.ingest(.text("零\0字符"))
        try check(try store!.fetch(order: .recent).first?.text == "零\0字符", "embedded NUL text preserved")
        try check(store!.diskBytes > 0,"disk usage available")
        let perm = try FileManager.default.attributesOfItem(atPath: dbURL.path)[.posixPermissions] as! NSNumber
        try check(perm.intValue == 0o600,"database owner-only file permissions")
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        let reader = ClipboardReader()
        board.clearContents(); board.setString("预先存在的合成文本",forType: .string); reader.baseline(board)
        try check(reader.readChange(board) == nil,"baseline never imports pre-existing clipboard")
        board.clearContents(); board.setString("重复外部合成",forType: .string)
        let once = reader.readChange(board); try check(once?.text == "重复外部合成","external copy captured")
        try check(reader.readChange(board) == nil,"unchanged clipboard not double-counted")
        board.clearContents(); board.setString("重复外部合成",forType: .string)
        let twice = reader.readChange(board); try check(twice?.id == once?.id,"same external content copied again captured")
        try store!.ingest(once!); try store!.ingest(twice!)
        try check(try store!.fetch(order: .frequent,search: "重复外部合成").first?.count == 2,"external duplicates increment stored count")
        try check(reader.write(.text("应用内复制合成"),to: board),"write text to isolated pasteboard")
        try check(reader.readChange(board) == nil,"own copy does not feed back")
        board.clearContents(); board.setString("应用内复制合成",forType: .string)
        try check(reader.readChange(board)?.text == "应用内复制合成","external same-as-own copy captured")
        for type in ClipboardReader.skippedTypes + ["com.example.password.secret"] {
            let item = NSPasteboardItem(); item.setString("绝不保存的合成秘密",forType: .string); item.setData(Data(),forType: .init(type))
            board.clearContents(); board.writeObjects([item])
            try check(reader.readChange(board) == nil,"sensitive marker skipped: \(type)")
        }
        board.clearContents(); board.setString(String(repeating: "a",count: ClipboardReader.maxTextBytes+1),forType: .string)
        try check(reader.readChange(board) == nil,"oversized text skipped")
        let fileItem = NSPasteboardItem(); fileItem.setString("file:///synthetic/never-opened",forType: .fileURL); fileItem.setString("synthetic",forType: .string)
        board.clearContents(); board.writeObjects([fileItem]); try check(reader.readChange(board) == nil,"file clipboard ignored without following URL")
        let image = NSImage(size: NSSize(width: 64,height: 48)); image.lockFocus(); NSColor.orange.setFill(); NSRect(x: 0,y: 0,width: 64,height: 48).fill(); image.unlockFocus()
        guard let imageValue = ClipPayload.image(image) else { throw TestFailure(description: "synthetic image encoding") }
        try store!.ingest(imageValue); try store!.ingest(imageValue)
        try check(try store!.payload(id: imageValue.id)?.data == imageValue.data,"image PNG round trip")
        try check(try store!.fetch(order: .recent,search: "图片").first?.count == 2,"image deduplication")
        reader.write(imageValue,to: board); try check(reader.readChange(board) == nil,"own image copy does not feed back")
        board.clearContents(); board.setData(imageValue.data,forType: .png)
        try check(reader.readChange(board)?.kind == .image,"external image captured")
        let suiteName = "local.clipgarden.tests.\(UUID().uuidString)"
        let prefs = UserDefaults(suiteName: suiteName)!
        defer { prefs.removePersistentDomain(forName: suiteName) }
        let model = GardenModel(store: store!,demo: true,preferences: prefs)
        model.consented = false; model.enabled = true
        model.pasteboard.clearContents(); model.pasteboard.setString("未同意不采集",forType: .string); model.poll()
        try check(try store!.fetch(order: .recent,search: "未同意不采集").isEmpty,"consent gate prevents collection")
        model.consented = true; model.enabled = false; model.poll()
        try check(try store!.fetch(order: .recent,search: "未同意不采集").isEmpty,"pause prevents collection")
        model.search = "不存在的合成内容"; try check(model.recent.isEmpty && model.frequent.isEmpty,"search updates both UI columns")
        model.search = ""; let target = model.recent.first!; model.copy(target); model.enabled = true; model.poll()
        try check(try store!.fetch(order: .recent).first?.count == target.count,"UI copy leaves frequency unchanged")
        try check(Shortcut(key: 49,modifiers: UInt32(cmdKey),label: "⌘空格").conflictWarning != nil,"common system shortcut rejected")
        try check(Shortcut.standard.conflictWarning == nil,"default shortcut passes static policy")
        let shortcut = Shortcut(key: 5,modifiers: UInt32(cmdKey|optionKey|controlKey),label: "⌃⌥⌘G")
        let hotkey1 = GlobalHotKey(); let hotkey2 = GlobalHotKey()
        let first = hotkey1.register(shortcut)
        try check(first == nil,"global hotkey registered on this Mac")
        try check(hotkey1.register(shortcut) == nil,"same active shortcut can be saved again")
        try check(hotkey2.register(shortcut) != nil,"duplicate registration reports conflict")
        try check(hotkey1.register(Shortcut(key: 49,modifiers: UInt32(cmdKey),label: "⌘空格")) != nil,"reserved replacement rejected, previous registration retained")
        let custom = Shortcut(key: 101,modifiers: UInt32(controlKey|optionKey|shiftKey),label: "⌃⌥⇧F9")
        model.saveShortcut(custom)
        let reopened = GardenModel(store: store!,demo: true,preferences: prefs)
        try check(reopened.shortcut == custom,"custom global shortcut persists across model reopen")
        model.saveShortcut(Shortcut(key: 49,modifiers: UInt32(cmdKey),label: "⌘空格"))
        try check(model.shortcut == custom,"failed shortcut replacement preserves saved shortcut")
        model.delete(target); try check(try store!.payload(id: target.id) == nil,"single record deletion")
        model.clear(); try check(try store!.count() == 0 && model.recent.isEmpty,"clear deletes database rows and refreshes UI")
        print("RESULT: \(checks) synthetic checks passed. No general clipboard reads or writes. No network.")
    }
}
