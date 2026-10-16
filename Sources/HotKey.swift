import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    let key: UInt32
    let modifiers: UInt32
    let label: String
    static let standard = Shortcut(key: 9, modifiers: UInt32(cmdKey | shiftKey), label: "⇧⌘V")
    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { return nil }
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        let names: [UInt16: String] = [49: "空格", 36: "↩", 48: "⇥", 51: "⌫", 53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        let name = names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "键 \(event.keyCode)"
        let prefix = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
        return Shortcut(key: UInt32(event.keyCode), modifiers: mods, label: prefix + name)
    }
    var conflictWarning: String? {
        let cmd = UInt32(cmdKey), opt = UInt32(optionKey), ctrl = UInt32(controlKey), shift = UInt32(shiftKey)
        if (key == 49 && [cmd, ctrl, cmd|opt, cmd|shift].contains(modifiers)) || (key == 48 && modifiers & cmd != 0) || (key == 53 && modifiers == cmd|opt) || ([18,19,20,21,23,26].contains(key) && modifiers == cmd|shift) || (key == 12 && modifiers == cmd|ctrl) { return "这个组合常被 macOS 系统功能占用，请换一个。" }
        if modifiers == cmd && [0,6,7,8,9,12,13,15,17,31,35,37,40,45,46,4].contains(key) { return "这个组合是常见编辑或应用快捷键，请加上 ⇧、⌥ 或 ⌃。" }
        return nil
    }
}

final class GlobalHotKey {
    private var reference: EventHotKeyRef?
    private var activeShortcut: Shortcut?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            instance.onPress?(); return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    deinit { if let reference { UnregisterEventHotKey(reference) }; if let handler { RemoveEventHandler(handler) } }
    func register(_ shortcut: Shortcut) -> String? {
        if let warning = shortcut.conflictWarning { return warning }
        if shortcut == activeShortcut { return nil }
        var next: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.key, shortcut.modifiers, EventHotKeyID(signature: 0x43475244, id: 1), GetApplicationEventTarget(), 0, &next)
        guard status == noErr else { return "注册失败（\(status)）：组合可能已被占用，请换一个。" }
        if let reference { UnregisterEventHotKey(reference) }
        reference = next; activeShortcut = shortcut
        return nil
    }
}
