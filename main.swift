import SwiftUI
import Carbon
import AppKit
import ServiceManagement

// MARK: - Model

struct Clip: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String?
    var image: Data?
    var pinned = false
}

final class Store: ObservableObject {
    static let shared = Store()
    @Published var clips: [Clip] = []
    @Published var selected = 0
    var lastChange = NSPasteboard.general.changeCount
    var maxUnpinned: Int {
        let v = UserDefaults.standard.integer(forKey: "maxClips")
        return v > 0 ? v : 25
    }

    func trim() {
        var n = 0
        clips = clips.filter { $0.pinned || { n += 1; return n <= maxUnpinned }() }
        selected = max(0, min(selected, ordered.count - 1))
    }

    let url: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("ClipBack")
        let old = base.appendingPathComponent("ClipboardHistory")   // pre-rename location
        if !fm.fileExists(atPath: d.path), fm.fileExists(atPath: old.path) {
            try? fm.moveItem(at: old, to: d)
        }
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("history.json")
    }()

    init() {
        if let d = try? Data(contentsOf: url), let c = try? JSONDecoder().decode([Clip].self, from: d) { clips = c }
    }

    // Pinned items first, like Windows
    @Published var query = ""

    var ordered: [Clip] {
        let all = clips.filter { $0.pinned } + clips.filter { !$0.pinned }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.text?.localizedCaseInsensitiveContains(q) == true }
    }

    func save() { try? JSONEncoder().encode(clips).write(to: url) }

    func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        var clip: Clip?
        if let s = pb.string(forType: .string), !s.isEmpty {
            clip = Clip(text: s)
        } else if let d = pb.data(forType: .png) ?? pb.data(forType: .tiff),
                  let png = NSBitmapImageRep(data: d)?.representation(using: .png, properties: [:]) {
            clip = Clip(image: png)
        }
        guard let c = clip else { return }
        clips.removeAll { !$0.pinned && $0.text == c.text && $0.image == c.image }
        clips.insert(c, at: 0)
        trim()
        save()
    }

    func togglePin(_ c: Clip) {
        if let i = clips.firstIndex(of: c) { clips[i].pinned.toggle(); save() }
    }
    func remove(_ c: Clip) {
        clips.removeAll { $0.id == c.id }
        selected = max(0, min(selected, ordered.count - 1)); save()
    }
    func clearAll() { clips.removeAll { !$0.pinned }; selected = 0; save() }

    func paste(_ c: Clip) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let t = c.text { pb.setString(t, forType: .string) }
        else if let d = c.image { pb.setData(d, forType: .png) }
        lastChange = pb.changeCount
        Panel.shared.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let src = CGEventSource(stateID: .combinedSessionState)
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down)
                e?.flags = .maskCommand
                e?.post(tap: .cghidEventTap)
            }
        }
    }
}

// MARK: - Floating panel (does not steal focus from the app you paste into)

final class Panel: NSPanel {
    static let shared = Panel()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: HistoryView().environmentObject(Store.shared))
    }

    override var canBecomeKey: Bool { true }
    override func resignKey() { super.resignKey(); orderOut(nil) }

    func toggle() {
        if isVisible { orderOut(nil); return }
        Store.shared.query = ""
        Store.shared.selected = 0
        let m = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(m) } ?? NSScreen.main!
        var o = NSPoint(x: m.x - 20, y: m.y - frame.height - 10)
        let v = screen.visibleFrame
        o.x = min(max(o.x, v.minX + 8), v.maxX - frame.width - 8)
        o.y = min(max(o.y, v.minY + 8), v.maxY - frame.height - 8)
        setFrameOrigin(o)
        makeKeyAndOrderFront(nil)
    }

    // Drag the window from anywhere: once the mouse moves a few points
    // with the button down, move the window instead of treating it as a click.
    var downPoint: NSPoint?
    var downOrigin = NSPoint.zero
    var dragging = false

    override func sendEvent(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown:
            downPoint = NSEvent.mouseLocation
            downOrigin = frame.origin
            dragging = false
        case .leftMouseDragged:
            if let p = downPoint {
                let m = NSEvent.mouseLocation
                let dx = m.x - p.x, dy = m.y - p.y
                if dragging || hypot(dx, dy) > 4 {
                    dragging = true
                    setFrameOrigin(NSPoint(x: downOrigin.x + dx, y: downOrigin.y + dy))
                    return
                }
            }
        case .leftMouseUp:
            downPoint = nil
            if dragging { dragging = false; return }
        case .keyDown:
            if handle(e) { return }
        default: break
        }
        super.sendEvent(e)
    }

    func handle(_ e: NSEvent) -> Bool {
        let s = Store.shared
        let has = s.ordered.indices.contains(s.selected)
        switch e.keyCode {
        case 126: s.selected = max(0, s.selected - 1)
        case 125: s.selected = min(s.ordered.count - 1, s.selected + 1)
        case 36, 76: if has { s.paste(s.ordered[s.selected]) }
        case 53:
            if s.query.isEmpty { orderOut(nil) } else { s.query = "" }
        case 51, 117:
            // ⌘⌫ deletes the selected clip; plain Delete edits the search text
            guard e.modifierFlags.contains(.command) else { return false }
            if has { s.remove(s.ordered[s.selected]) }
        default: return false
        }
        return true
    }
}

// MARK: - Views

struct Row: View {
    let clip: Clip
    let sel: Bool
    @EnvironmentObject var s: Store

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let t = clip.text {
                Text(t).lineLimit(3).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
            } else if let d = clip.image, let i = NSImage(data: d) {
                Image(nsImage: i).resizable().scaledToFit().frame(maxHeight: 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { s.togglePin(clip) } label: { Image(systemName: clip.pinned ? "pin.fill" : "pin") }
                .buttonStyle(.plain)
            Button { s.remove(clip) } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill(sel ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.07)))
        .contentShape(Rectangle())
        .onTapGesture { s.paste(clip) }
    }
}

struct HistoryView: View {
    @EnvironmentObject var s: Store
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Clipboard").font(.headline)
                Spacer()
                Button("Clear all") { s.clearAll() }.buttonStyle(.plain).foregroundColor(.accentColor)
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search", text: $s.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !s.query.isEmpty {
                    Button { s.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.07)))

            if s.ordered.isEmpty {
                Spacer()
                Text(s.query.isEmpty ? "Nothing here yet.\nCopy something to get started."
                                     : "No matches")
                    .multilineTextAlignment(.center).foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(Array(s.ordered.enumerated()), id: \.element.id) { i, c in
                                Row(clip: c, sel: i == s.selected).id(c.id)
                            }
                        }
                    }
                    .onChange(of: s.selected) { _, n in
                        if s.ordered.indices.contains(n) { proxy.scrollTo(s.ordered[n].id) }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 360, height: 480)
        .onChange(of: s.query) { _, _ in s.selected = 0 }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { n in
            if n.object is Panel { DispatchQueue.main.async { searchFocused = true } }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Customizable hotkey

enum HotKey {
    static var ref: EventHotKeyRef?
    static var installed = false

    static var label: String {
        UserDefaults.standard.string(forKey: "label") ?? "⌃⌘V"
    }

    static func register() {
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { Panel.shared.toggle() }
                return noErr
            }, 1, &spec, nil, nil)
            installed = true
        }
        if let r = ref { UnregisterEventHotKey(r) }
        let d = UserDefaults.standard
        let code = d.object(forKey: "code") as? Int ?? 9
        let mods = d.object(forKey: "mods") as? Int ?? (cmdKey | controlKey)
        RegisterEventHotKey(UInt32(code), UInt32(mods), EventHotKeyID(signature: 0x434C4950, id: 1),
                            GetApplicationEventTarget(), 0, &ref)
    }
}

struct SettingsView: View {
    @State private var recording = false
    @State private var label = HotKey.label
    @State private var monitor: Any?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("maxClips") private var maxClips = 25

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section {
                LabeledContent("Change shortcut") {
                    Button { recording ? stop() : start() } label: {
                        Text(recording ? "Press shortcut…" : label)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .frame(minWidth: 110)
                    }
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Use at least one modifier key (⌘ ⌃ ⌥ ⇧). Press Esc to cancel.")
            }

            Section {
                Picker("Clips to keep", selection: $maxClips) {
                    ForEach([10, 25, 50, 100, 200], id: \.self) { Text("\($0)").tag($0) }
                }
                .onChange(of: maxClips) { _, _ in
                    Store.shared.trim()
                    Store.shared.save()
                }
            } header: {
                Text("History")
            } footer: {
                Text("The oldest clips are removed first. Pinned clips are always kept and don't count toward this limit.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 400)
    }

    func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { stop(); return nil }
            let f = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var mods = 0, sym = ""
            if f.contains(.control) { mods |= controlKey; sym += "⌃" }
            if f.contains(.option) { mods |= optionKey; sym += "⌥" }
            if f.contains(.shift) { mods |= shiftKey; sym += "⇧" }
            if f.contains(.command) { mods |= cmdKey; sym += "⌘" }
            guard mods != 0 else { return nil }
            label = sym + (e.charactersIgnoringModifiers ?? "?").uppercased()
            let d = UserDefaults.standard
            d.set(Int(e.keyCode), forKey: "code"); d.set(mods, forKey: "mods"); d.set(label, forKey: "label")
            HotKey.register()
            stop()
            return nil
        }
    }

    func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var settings: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipBack")
        let m = NSMenu()
        m.addItem(withTitle: "Show History", action: #selector(show), keyEquivalent: "")
        m.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        m.addItem(.separator())
        m.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        m.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? nil : self }
        item.menu = m
        HotKey.register()
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in Store.shared.poll() }
    }

    @objc func show() { Panel.shared.toggle() }

    @objc func openSettings() {
        if settings == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Settings"
            w.contentView = NSHostingView(rootView: SettingsView())
            w.isReleasedWhenClosed = false
            w.center()
            settings = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()