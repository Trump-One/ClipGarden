import SwiftUI
import AppKit

let ink = Color(red: 0.19, green: 0.24, blue: 0.22)
let cream = Color(red: 0.98, green: 0.96, blue: 0.90)
let mint = Color(red: 0.77, green: 0.88, blue: 0.82)
let peach = Color(red: 1, green: 0.77, blue: 0.60)

struct Sticker: ViewModifier {
    var fill: Color = .white
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content.background(fill).clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(ink, lineWidth: 1.5))
            .shadow(color: ink.opacity(0.13), radius: 0, x: 2, y: 3)
    }
}
extension View { func sticker(_ fill: Color = .white, radius: CGFloat = 18) -> some View { modifier(Sticker(fill: fill, radius: radius)) } }

struct GardenButton: ButtonStyle {
    var fill: Color = mint
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 15).padding(.vertical, 10)
            .foregroundStyle(ink).background(fill).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink, lineWidth: 1.4))
            .offset(y: configuration.isPressed ? 2 : 0)
            .shadow(color: ink.opacity(0.15), radius: 0, x: 1, y: configuration.isPressed ? 0 : 2)
    }
}

struct Mascot: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17).fill(mint).frame(width: 58,height: 64).rotationEffect(.degrees(-8))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(ink,lineWidth: 2).frame(width: 58,height: 64).rotationEffect(.degrees(-8)))
            RoundedRectangle(cornerRadius: 5).fill(cream).frame(width: 27,height: 12).overlay(RoundedRectangle(cornerRadius: 5).stroke(ink,lineWidth: 2)).offset(y: -30)
            HStack(spacing: 13) { Circle().frame(width: 5,height: 7); Circle().frame(width: 5,height: 7) }.offset(y: -1)
            Text("⌣").font(.system(size: 23,weight: .bold)).offset(y: 12)
            HStack(spacing: 26) { Ellipse().fill(peach).frame(width: 9,height: 5); Ellipse().fill(peach).frame(width: 9,height: 5) }.offset(y: 7)
        }.foregroundStyle(ink).frame(width: 78,height: 82).accessibilityLabel("小夹子吉祥物")
    }
}

struct MainView: View {
    @ObservedObject var model: GardenModel
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Mascot()
                VStack(alignment: .leading,spacing: 5) {
                    HStack(alignment: .firstTextBaseline,spacing: 9) {
                        Text("剪贴花园").font(.system(size: 27,weight: .heavy,design: .rounded))
                        Text("CLIP GARDEN").font(.system(size: 10,weight: .bold,design: .monospaced)).tracking(1.6).foregroundStyle(ink.opacity(0.55))
                    }
                    Text("复制过的小事，都替你记得。").font(.system(size: 13)).foregroundStyle(ink.opacity(0.65))
                }
                Spacer()
                if model.demo { Text("合成数据演示").font(.system(size: 11,weight: .bold)).padding(8).sticker(peach,radius: 9) }
                Button { if model.consented { model.setEnabled(!model.enabled) } } label: {
                    Label(model.enabled ? "暂停记录" : "恢复记录",systemImage: model.enabled ? "pause.fill" : "play.fill")
                }.buttonStyle(GardenButton(fill: .white)).disabled(!model.consented || model.demo)
                Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 16) }.buttonStyle(GardenButton(fill: cream)).help("设置与快捷键")
            }.padding(.horizontal, 27).padding(.top, 12).padding(.bottom, 15)
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 17,weight: .medium))
                TextField("找找以前复制过的文字…",text: $model.search).textFieldStyle(.plain).font(.system(size: 14)).focused($searchFocused)
                if !model.search.isEmpty { Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
                Text("⌘F").font(.system(size: 12,design: .monospaced)).foregroundStyle(ink.opacity(0.45))
            }.padding(15).sticker(.white,radius: 13).padding(.horizontal, 30).padding(.bottom, 22)
            HStack(alignment: .top,spacing: 24) {
                HistoryColumn(model: model,title: "最近的小记忆",subtitle: "按最后复制时间 · 新的在上",symbol: "clock.arrow.circlepath",color: mint,records: model.recent,frequent: false)
                HistoryColumn(model: model,title: "常用的心头好",subtitle: "按累计复制次数 · 常用在上",symbol: "sparkles",color: peach,records: model.frequent,frequent: true)
            }.padding(.horizontal,30)
            HStack(spacing: 7) {
                Circle().fill(model.demo ? Color.orange : model.enabled ? Color(red: 0.2,green: 0.53,blue: 0.37) : Color.gray).frame(width: 7,height: 7)
                Text(model.demo ? "演示模式 · 不读取真实剪贴板" : model.enabled ? "正在本机悄悄记住" : "记录已暂停").font(.system(size: 11,weight: .medium))
                Text("·  \(model.total) 条记忆  ·  \(ByteCountFormatter.string(fromByteCount: model.diskBytes,countStyle: .file))").font(.system(size: 11)).foregroundStyle(ink.opacity(0.55))
                Spacer()
                Text(model.shortcut.label).font(.system(size: 11,weight: .semibold,design: .monospaced)).padding(.horizontal,7).padding(.vertical,4).background(ink.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 5))
                Text("随时唤起").font(.system(size: 11)).foregroundStyle(ink.opacity(0.55))
                if model.shortcutMessage?.contains("失败") == true { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).help(model.shortcutMessage ?? "") }
            }.padding(.horizontal,31).padding(.vertical,16)
        }.foregroundStyle(ink).background(cream).frame(minWidth: 850,minHeight: 650)
            .background(Button("") { searchFocused = true }.keyboardShortcut("f",modifiers: .command).hidden())
            .overlay(alignment: .bottom) { if let message = model.toast { Text(message).font(.system(size: 13,weight: .semibold)).padding(13).sticker(mint,radius: 12).padding(.bottom,54).transition(.opacity) } }
            .overlay { if !model.consented { ConsentView(model: model) } }
            .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
            .sheet(item: $model.preview) { record in PreviewView(model: model,record: record) }
            .alert("操作未完成",isPresented: Binding(get: { model.error != nil },set: { if !$0 { model.error = nil } })) { Button("知道了") { model.error = nil } } message: { Text(model.error ?? "") }
    }
}

struct HistoryColumn: View {
    @ObservedObject var model: GardenModel
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let records: [ClipRecord]
    let frequent: Bool
    var body: some View {
        VStack(alignment: .leading,spacing: 13) {
            HStack(spacing: 11) {
                Image(systemName: symbol).font(.system(size: 18,weight: .semibold)).frame(width: 39,height: 39).sticker(color,radius: 12)
                VStack(alignment: .leading,spacing: 4) { Text(title).font(.system(size: 18,weight: .bold,design: .rounded)); Text(subtitle).font(.system(size: 11)).foregroundStyle(ink.opacity(0.58)) }
                Spacer()
                Text(frequent ? "02" : "01").font(.system(size: 25,weight: .light,design: .rounded)).foregroundStyle(ink.opacity(0.2))
            }.padding(.bottom,4)
            ScrollView {
                LazyVStack(spacing: 13) {
                    if records.isEmpty {
                        VStack(spacing: 15) { Text(model.search.isEmpty ? "🌱" : "🔎").font(.system(size: 42)); Text(model.search.isEmpty ? "花园还空着" : "没有找到这条记忆").font(.system(size: 16,weight: .bold)); Text(model.search.isEmpty ? "开启记录后，复制一段文字试试。\n以前的剪贴板不会被自动导入。" : "换个关键词，再找找看。").font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(ink.opacity(0.6)) }.frame(maxWidth: .infinity).padding(.vertical,70)
                    }
                    ForEach(Array(records.enumerated()),id: \.element.id) { index,record in ClipCard(model: model,record: record,color: color,rank: frequent ? index+1 : nil) }
                    if records.count >= model.visibleLimit { Button("再看看更早的记忆") { model.loadMore() }.buttonStyle(GardenButton(fill: cream)).padding(6) }
                }.padding(.horizontal,3).padding(.top,2).padding(.bottom,10)
            }.scrollIndicators(.hidden)
        }.frame(maxWidth: .infinity)
    }
}

struct ClipCard: View {
    @ObservedObject var model: GardenModel
    let record: ClipRecord
    let color: Color
    let rank: Int?
    @State private var hovered = false
    var body: some View {
        VStack(alignment: .leading,spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: record.kind == .text ? "text.alignleft" : "photo").font(.system(size: 11))
                Text(record.kind == .text ? "文字便签" : "图片灵感").font(.system(size: 10,weight: .semibold))
                Spacer()
                if let rank, rank <= 3 { Text("#\(rank)").font(.system(size: 10,weight: .bold,design: .rounded)).padding(.horizontal,6).padding(.vertical,3).background(color).clipShape(Capsule()) }
                Text("\(record.count) 次").font(.system(size: 10,weight: .bold)).padding(.horizontal,7).padding(.vertical,3).background(color.opacity(0.45)).clipShape(Capsule())
            }.foregroundStyle(ink.opacity(0.65))
            Button { model.copy(record) } label: {
                Group {
                    if record.kind == .image,let data = record.thumbnail,let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 105).background(mint.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 9)) }
                    else { Text(record.text).font(.system(size: 13,weight: .medium)).lineSpacing(4).lineLimit(3).multilineTextAlignment(.leading).frame(maxWidth: .infinity,alignment: .leading).frame(minHeight: 37,alignment: .top) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("点击复制内容")
            HStack(spacing: 8) {
                Text(record.lastAt,style: .relative).font(.system(size: 10)).foregroundStyle(ink.opacity(0.48)).lineLimit(1)
                Spacer(minLength: 0)
                Button { model.preview = record } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11)) }.buttonStyle(.plain).help("预览完整内容").accessibilityLabel("预览完整内容")
                Button { model.delete(record) } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain).foregroundStyle(ink.opacity(hovered ? 0.7 : 0.4)).help("删除这条记录").accessibilityLabel("删除这条记录")
                Button { model.copy(record) } label: { Image(systemName: "doc.on.doc").font(.system(size: 11,weight: .semibold)); Text("复制").font(.system(size: 10,weight: .semibold)) }.buttonStyle(.plain).padding(.horizontal,8).padding(.vertical,5).background(hovered ? color : cream).clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityLabel("复制记录")
            }
        }.padding(15).sticker(hovered ? Color.white : Color(red: 1,green: 0.995,blue: 0.975),radius: 15).onHover { hovered = $0 }
            .contextMenu { Button("复制") { model.copy(record) }; Button("预览") { model.preview = record }; Divider(); Button("删除",role: .destructive) { model.delete(record) } }
    }
}

struct ConsentView: View {
    @ObservedObject var model: GardenModel
    var body: some View {
        ZStack {
            cream.opacity(0.96)
            VStack(spacing: 19) {
                Mascot().scaleEffect(1.25).padding(.bottom,5)
                Text("给剪贴板一个小花园").font(.system(size: 26,weight: .heavy,design: .rounded))
                Text("从下一次复制开始，替你保存文字和图片。\n所有记忆只存在这台 Mac，不联网上传。").font(.system(size: 14)).lineSpacing(6).multilineTextAlignment(.center)
                VStack(alignment: .leading,spacing: 13) {
                    Label("需要你确认后，才会开始持续记录",systemImage: "hand.raised")
                    Label("没有自动过期；可随时暂停、删除或清空",systemImage: "leaf")
                    Label("跳过可识别的敏感标记；普通文本中的秘密无法自动识别",systemImage: "lock")
                    Label("本地数据库未加密，敏感操作前请暂停记录",systemImage: "externaldrive")
                }.font(.system(size: 12)).padding(20).sticker(.white,radius: 14)
                HStack(spacing: 14) {
                    Button("暂不开启") { model.consented = true; model.setEnabled(false) }.buttonStyle(GardenButton(fill: cream))
                    Button("同意并开启记录") { model.accept() }.buttonStyle(GardenButton(fill: mint)).keyboardShortcut(.defaultAction)
                }
                Text("不会导入当前已有的剪贴板，也不会自动开机启动。").font(.system(size: 11)).foregroundStyle(ink.opacity(0.6))
            }.padding(32)
        }.foregroundStyle(ink)
    }
}

struct SettingsView: View {
    @ObservedObject var model: GardenModel
    @State private var eventMonitor: Any? = nil
    var body: some View {
        VStack(alignment: .leading,spacing: 20) {
            HStack { Text("花园设置").font(.system(size: 24,weight: .heavy,design: .rounded)); Spacer(); Button("完成") { model.showSettings = false }.buttonStyle(GardenButton(fill: mint)) }
            VStack(alignment: .leading,spacing: 12) {
                Label("随时叫出小花园",systemImage: "keyboard").font(.system(size: 15,weight: .bold))
                HStack { Text("全局唤起快捷键").font(.system(size: 13)); Spacer(); Button(model.recording ? "请按组合键… Esc 取消" : model.shortcut.label) { model.recording.toggle() }.buttonStyle(GardenButton(fill: model.recording ? peach : cream)).accessibilityLabel("录制全局快捷键") }
                Text(model.shortcutMessage ?? "点击右侧后按下组合键，需包含 ⌘、⌥ 或 ⌃。").font(.system(size: 12)).foregroundStyle(model.shortcutMessage?.contains("失败") == true ? Color.red : ink.opacity(0.7))
                Text("会提示常见系统保留组合与注册失败。macOS 没有统一接口列出所有第三方快捷键；请同时检查其他软件的设置。").font(.system(size: 11)).foregroundStyle(ink.opacity(0.55)).fixedSize(horizontal: false,vertical: true)
            }.padding(18).sticker(.white,radius: 15)
            VStack(alignment: .leading,spacing: 12) {
                Label("本地记忆盒",systemImage: "externaldrive").font(.system(size: 15,weight: .bold))
                Text("\(model.total) 条记录 · 已占用 \(ByteCountFormatter.string(fromByteCount: model.diskBytes,countStyle: .file))").font(.system(size: 13))
                Text("长期保留，不自动过期。文字和图片会持续占用磁盘；删除后回收数据库空间。应用内复制不增加次数，外部重复复制会累计。").font(.system(size: 12)).lineSpacing(3).fixedSize(horizontal: false,vertical: true)
                Text("支持纯文本与 PNG / TIFF 图片；不收集文件、富文本格式或图片中的文字。单条文字上限 2 MB，图片 20 MB / 3000 万像素。").font(.system(size: 11)).foregroundStyle(ink.opacity(0.6)).fixedSize(horizontal: false,vertical: true)
                HStack {
                    Button("打开数据文件夹") { NSWorkspace.shared.open(model.store.url.deletingLastPathComponent()) }.buttonStyle(GardenButton(fill: cream))
                    Spacer()
                    Button("清空全部历史…",role: .destructive) { model.showClear = true }.buttonStyle(GardenButton(fill: peach))
                }
            }.padding(18).sticker(.white,radius: 15)
            Text("隐私提示：敏感标记并非所有软件都会提供。复制密码、验证码或机密前请暂停。数据库没有额外加密，也不会被应用上传；系统备份仍可能包含该文件。").font(.system(size: 11)).foregroundStyle(ink.opacity(0.6)).lineSpacing(3)
            HStack { Text("剪贴花园 1.0 · Made for quiet little memories").font(.system(size: 10,design: .monospaced)); Spacer(); Button("退出应用") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 11)) }.foregroundStyle(ink.opacity(0.5))
        }.padding(28).frame(width: 590).foregroundStyle(ink).background(cream)
            .alert("清空所有记忆？",isPresented: $model.showClear) { Button("取消",role: .cancel) {}; Button("清空历史",role: .destructive) { model.clear() } } message: { Text("所有文字、图片和复制次数都将删除，无法在应用中撤销。当前系统剪贴板和系统备份不受影响。") }
            .onAppear { eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard model.recording else { return event }
                if event.keyCode == 53 { model.recording = false; return nil }
                guard let shortcut = Shortcut.from(event) else { model.shortcutMessage = "请至少按住 ⌘、⌥ 或 ⌃ 中的一个。"; return nil }
                model.recording = false; model.saveShortcut(shortcut); return nil
            } }
            .onDisappear { model.recording = false; if let eventMonitor { NSEvent.removeMonitor(eventMonitor) } }
    }
}

struct PreviewView: View {
    @ObservedObject var model: GardenModel
    let record: ClipRecord
    @State private var image: NSImage? = nil
    var body: some View {
        VStack(alignment: .leading,spacing: 17) {
            HStack { Label("记忆放大镜",systemImage: "sparkle.magnifyingglass").font(.system(size: 20,weight: .bold)); Spacer(); Button("完成") { model.preview = nil }.buttonStyle(GardenButton(fill: cream)) }
            HStack { Text("累计复制 \(record.count) 次"); Spacer(); Text(ByteCountFormatter.string(fromByteCount: Int64(record.byteCount),countStyle: .file)) }.font(.system(size: 12)).foregroundStyle(ink.opacity(0.65))
            ScrollView {
                if record.kind == .text { Text(record.text).font(.system(size: 14)).lineSpacing(6).textSelection(.enabled).frame(maxWidth: .infinity,alignment: .leading).padding(20) }
                else if let image { Image(nsImage: image).resizable().scaledToFit().padding(14) }
            }.frame(height: 310).sticker(.white,radius: 13)
            VStack(alignment: .leading,spacing: 5) { Text("首次记录：\(record.firstAt.formatted(date: .numeric,time: .standard))"); Text("最后复制：\(record.lastAt.formatted(date: .numeric,time: .standard))") }.font(.system(size: 11)).foregroundStyle(ink.opacity(0.6))
            HStack { Button("删除这条",role: .destructive) { model.delete(record) }.buttonStyle(GardenButton(fill: cream)); Spacer(); Button("复制到剪贴板") { model.copy(record); model.preview = nil }.buttonStyle(GardenButton(fill: mint)) }
        }.padding(25).frame(width: 630).foregroundStyle(ink).background(cream)
            .onAppear { if record.kind == .image,let value = try? model.store.payload(id: record.id) { image = NSImage(data: value.data) } }
    }
}
