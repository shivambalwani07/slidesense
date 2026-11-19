import Foundation
import SwiftUI

/// Observable mirror of the accessibility permission so the settings window
/// can re-render the permission row when the system state changes.
final class PermissionState: ObservableObject {
    @Published private(set) var isTrusted: Bool

    /// Where `refresh()` reads the current state from. Defaults to the real
    /// accessibility check; tests inject a stub.
    private let provider: () -> Bool

    init(provider: @escaping () -> Bool = { AccessibilityPermission.isTrusted }) {
        self.provider = provider
        self.isTrusted = provider()
    }

    /// Fixed-value convenience used by previews and snapshots.
    convenience init(isTrusted: Bool) {
        self.init(provider: { isTrusted })
    }

    func refresh() {
        let current = provider()
        if current != isTrusted {
            isTrusted = current
        }
    }
}

/// The tabs of the settings window. Public so the app's snapshot tooling can
/// drive the window programmatically.
public enum SettingsTab: String, CaseIterable, Hashable, Identifiable {
    case edges
    case feel
    case extras
    case startup
    case general
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .edges: return "Edges"
        case .feel: return "Feel"
        case .extras: return "Media"
        case .custom: return "Custom"
        case .startup: return "Startup"
        case .general: return "General"
        }
    }
}

/// The SwiftUI content of the settings window, using the standard macOS
/// preferences pattern: a tab strip over grouped forms.
struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var permissionState: PermissionState
    @Binding var selection: SettingsTab

    var body: some View {
        TabView(selection: $selection) {
            SettingsTabContent(tab: .edges, store: store, permissionState: permissionState)
                .tabItem { Text(SettingsTab.edges.title) }
                .tag(SettingsTab.edges)

            SettingsTabContent(tab: .feel, store: store, permissionState: permissionState)
                .tabItem { Text(SettingsTab.feel.title) }
                .tag(SettingsTab.feel)

            SettingsTabContent(tab: .extras, store: store, permissionState: permissionState)
                .tabItem { Text(SettingsTab.extras.title) }
                .tag(SettingsTab.extras)

            SettingsTabContent(tab: .startup, store: store, permissionState: permissionState)
                .tabItem { Text(SettingsTab.startup.title) }
                .tag(SettingsTab.startup)

            SettingsTabContent(tab: .general, store: store, permissionState: permissionState)
                .tabItem { Text(SettingsTab.general.title) }
                .tag(SettingsTab.general)

            SettingsTabContent(tab: .custom, store: store, permissionState: permissionState)
                .tabItem { Text(SettingsTab.custom.title) }
                .tag(SettingsTab.custom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The grouped form for one tab. Kept separate from `SettingsView` so each tab
/// can be measured on its own with `NSHostingView.fittingSize`.
struct SettingsTabContent: View {
    let tab: SettingsTab
    @ObservedObject var store: SettingsStore
    @ObservedObject var permissionState: PermissionState

    @State private var showRestoreConfirmation = false
    @State private var customEdge: Edge = .left

    var body: some View {
        Group {
            switch tab {
            case .edges: edgesForm
            case .feel: feelForm
            case .extras: extrasForm
            case .custom: customForm
            case .startup: startupForm
            case .general: generalForm
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Edges

    private var edgesForm: some View {
        Form {
            Section {
                LabeledContent("Left Edge") {
                    actionPicker($store.settings.leftEdge)
                }
                LabeledContent("Right Edge") {
                    actionPicker($store.settings.rightEdge)
                }
                Toggle("Swap Sides", isOn: swappedBinding)
                    .toggleStyle(.switch)
                LabeledContent("Edge Width") {
                    slider($store.settings.edgeWidth, in: 0.05...0.45, step: 0.01) {
                        Text(percent(store.settings.edgeWidth))
                    }
                }
                Toggle("Bottom Quarter Only", isOn: $store.settings.bottomQuarterOnly)
                    .toggleStyle(.switch)
                Toggle("Flip Vertical Edges", isOn: $store.settings.flipVerticalEdges)
                    .toggleStyle(.switch)
            } header: {
                Text("Edges")
            } footer: {
                Text("Drag along an edge of the trackpad to change its level. Bottom Quarter Only restricts gestures to the lower quarter, and Flip Vertical Edges fixes a trackpad that reports the axis backwards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Sensitivity") {
                    slider($store.settings.sensitivity, in: 0.5...2.5, step: 0.05) {
                        Text(String(format: "%.2f×", store.settings.sensitivity))
                    }
                }
                LabeledContent("Require Modifier") {
                    Picker("Require Modifier", selection: $store.settings.requireModifier) {
                        ForEach(ModifierRequirement.allCases) { modifier in
                            Text(modifier.label).tag(modifier)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            } header: {
                Text("Sensitivity")
            } footer: {
                Text("Sensitivity controls how far a slide has to travel to cover the full range. Require Modifier prevents accidental slides.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Feel

    private var feelForm: some View {
        Form {
            Section {
                Toggle("Freeze Cursor", isOn: $store.settings.freezeCursor)
                    .toggleStyle(.switch)
                Toggle("Precise Sliding", isOn: $store.settings.preciseSliding)
                    .toggleStyle(.switch)
                Toggle("Fine Control with ⇧⌥", isOn: $store.settings.fineControlWithModifiers)
                    .toggleStyle(.switch)
            } header: {
                Text("While Sliding")
            } footer: {
                Text("Precise Sliding uses quarter steps without modifiers. Fine Control narrows the step size while ⇧ and ⌥ are held.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Haptics", isOn: $store.settings.hapticsEnabled)
                    .toggleStyle(.switch)
                LabeledContent("Strength") {
                    Picker("Strength", selection: $store.settings.hapticStrength) {
                        ForEach(HapticStrength.allCases) { strength in
                            Text(strength.label).tag(strength)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .disabled(!store.settings.hapticsEnabled)
                }
            } header: {
                Text("Haptics")
            } footer: {
                Text("A soft tick for every step of the level.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Extras

    private var extrasForm: some View {
        Form {
            Section {
                Toggle("Double-Tap Top Right", isOn: $store.settings.quickMuteEnabled)
                    .toggleStyle(.switch)
            } header: {
                Text("Quick Mute")
            } footer: {
                Text("Mutes or unmutes when you double-tap the top-right corner of the trackpad.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Enable Bottom Edge", isOn: $store.settings.mediaStripEnabled)
                    .toggleStyle(.switch)
                Picker("Action", selection: $store.settings.bottomEdgeAction) {
                    ForEach(BottomEdgeAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                .disabled(!store.settings.mediaStripEnabled)
                if store.settings.bottomEdgeAction == .tracks {
                    Toggle("Reverse Swipe", isOn: $store.settings.mediaStripReverse)
                        .toggleStyle(.switch)
                        .disabled(!store.settings.mediaStripEnabled)
                    Toggle("Tap to Play/Pause", isOn: $store.settings.tapToPlayEnabled)
                        .toggleStyle(.switch)
                        .disabled(!store.settings.mediaStripEnabled)
                } else {
                    ShortcutEditor(shortcut: $store.settings.bottomShortcut)
                    Button("Use Full-Screen Screenshot Shortcut") {
                        store.settings.bottomShortcut = ShortcutConfiguration()
                    }
                }
            } header: {
                Text("Bottom Edge")
            } footer: {
                Text(store.settings.bottomEdgeAction == .tracks
                     ? "Swipe along the bottom edge to skip tracks; double-tap to play or pause."
                     : "Swipe either direction to send your shortcut once. Default: ⌘⇧3 for a native screenshot. Add Control to copy to the clipboard instead. Use macOS Screenshot (⌘⇧5) to choose the save location and floating thumbnail.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var selectedCustomShortcuts: Binding<DirectionalShortcuts> {
        Binding(get: { store.settings.customShortcuts[customEdge] ?? DirectionalShortcuts() },
                set: { store.settings.customShortcuts[customEdge] = $0 })
    }

    private var customForm: some View {
        Form {
            Section {
                Picker("Edge", selection: $customEdge) {
                    ForEach(Edge.allCases, id: \.self) { edge in Text(edge.label).tag(edge) }
                }
                Toggle("Use Custom Shortcuts", isOn: selectedCustomShortcuts.enabled)
                    .toggleStyle(.switch)
            } footer: {
                Text("Replaces the selected edge’s normal action. Each swipe sends one shortcut; lift your finger before the next swipe. Requires Accessibility access.")
            }
            Section(customEdge == .bottom ? "Swipe Right" : "Swipe Up") {
                ShortcutEditor(shortcut: selectedCustomShortcuts.positive).id(customEdge)
            }
            .disabled(!selectedCustomShortcuts.wrappedValue.enabled)
            Section(customEdge == .bottom ? "Swipe Left" : "Swipe Down") {
                ShortcutEditor(shortcut: selectedCustomShortcuts.negative).id(customEdge)
            }
            .disabled(!selectedCustomShortcuts.wrappedValue.enabled)
        }
        .formStyle(.grouped)
    }

    // MARK: - Startup

    private var startupForm: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: $store.settings.openAtLogin)
                    .toggleStyle(.switch)
                    .disabled(!LoginItem.isSupported)
            } header: {
                Text("Startup")
            } footer: {
                if LoginItem.isSupported {
                    Text("Launches SlideSense when you log in.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Available when SlideSense runs from an app bundle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Check for Updates Automatically", isOn: $store.settings.automaticallyChecksForUpdates)
                    .toggleStyle(.switch)
                LabeledContent("Version") {
                    Text(Self.appVersion)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Button("Check Now…") {
                    NotificationCenter.default.post(name: .slideSenseCheckForUpdates, object: nil)
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Updates come from GitHub releases and are verified against the published SHA-256 before they are installed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
    }

    // MARK: - General

    private var generalForm: some View {
        Form {
            Section {
                LabeledContent("Accessibility") {
                    if permissionState.isTrusted {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Granted")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Open System Settings…") {
                            AccessibilityPermission.requestIfNeeded()
                            AccessibilityPermission.openSystemSettings()
                            permissionState.refresh()
                        }
                    }
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Accessibility access enables media keys and custom keyboard shortcuts. Volume and brightness control work without it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show HUD", isOn: $store.settings.showHUD)
                    .toggleStyle(.switch)
                LabeledContent("Appearance") {
                    Picker("Appearance", selection: $store.settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            } header: {
                Text("HUD")
            } footer: {
                Text("The HUD appears while you slide an edge.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Restore Defaults…") {
                    showRestoreConfirmation = true
                }
                .buttonStyle(.bordered)
            } header: {
                Text("Reset")
            } footer: {
                Text("SlideSense \(Self.appVersion) · MIT licensed")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert("Restore default settings?", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore Defaults", role: .destructive) {
                store.resetToDefaults()
            }
        } message: {
            Text("All edge, feel, extra, and appearance settings will return to their defaults.")
        }
    }

    // MARK: - Controls

    private func actionPicker(_ selection: Binding<EdgeAction>) -> some View {
        Picker("", selection: selection) {
            ForEach(EdgeAction.allCases) { action in
                Text(action.label).tag(action)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private func slider(
        _ value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        @ViewBuilder valueText: () -> Text
    ) -> some View {
        // A stepped SwiftUI slider draws tick marks on macOS, which no Apple
        // preferences slider does. Keep it continuous and round on the way in.
        let snapped = Binding<Double>(
            get: { value.wrappedValue },
            set: { raw in
                let clamped = min(max(raw, range.lowerBound), range.upperBound)
                let rounded = (clamped / step).rounded() * step
                if rounded != value.wrappedValue {
                    value.wrappedValue = rounded
                }
            }
        )
        return HStack(spacing: 8) {
            Slider(value: snapped, in: range)
            valueText()
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(width: 280)
    }

    private var swappedBinding: Binding<Bool> {
        Binding(
            get: { store.settings.swapped },
            set: { store.settings.swapped = $0 }
        )
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private static var appVersion: String {
        SlideSenseVersion.marketing
    }
}

private struct ShortcutEditor: View {
    @Binding var shortcut: ShortcutConfiguration
    @State private var eventMonitor: Any?
    @State private var recordingHint = ""
    @State private var useCustomAction = false

    var body: some View {
        Group {
            Picker("Action", selection: actionSelection) {
                ForEach(ShortcutConfiguration.presets, id: \.name) { preset in
                    Text(preset.name).tag(preset.name)
                }
                Text("Custom — Record Shortcut").tag("__custom")
            }
            LabeledContent("Shortcut", value: shortcut.displayName)
            if actionSelection.wrappedValue == "__custom" {
                Button(eventMonitor == nil ? "Record Shortcut" : "Recording… (Esc to Cancel)") {
                    beginRecording()
                }
                if eventMonitor != nil {
                    Text(recordingHint).font(.caption).foregroundStyle(.secondary)
                }
            }
            if !shortcut.isValid {
                Text("Choose a modifier with a key, or a function key.").foregroundStyle(.red)
            }
        }
        .onDisappear { stopRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            stopRecording()
        }
    }

    private var actionSelection: Binding<String> {
        Binding(get: {
            if useCustomAction { return "__custom" }
            return ShortcutConfiguration.presets.first { $0.shortcut == shortcut }?.name ?? "__custom"
        }, set: { action in
            stopRecording()
            useCustomAction = action == "__custom"
            if let preset = ShortcutConfiguration.presets.first(where: { $0.name == action }) {
                shortcut = preset.shortcut
            }
        })
    }

    private func beginRecording() {
        stopRecording()
        recordingHint = "Press your shortcut. For macOS-reserved combinations, choose a preset."
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { event in
            if event.type == .leftMouseDown {
                stopRecording()
                return event
            }
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            guard !event.isARepeat else { return nil }
            let flags = event.modifierFlags
            let recorded = ShortcutConfiguration(keyCode: event.keyCode,
                command: flags.contains(.command), shift: flags.contains(.shift),
                option: flags.contains(.option), control: flags.contains(.control))
            guard recorded.isValid else {
                recordingHint = "Use a modifier with a key, or a function key."
                return nil
            }
            shortcut = recorded
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }
}
