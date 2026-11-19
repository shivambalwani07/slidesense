import Foundation

/// Defaults to the macOS full-screen screenshot shortcut (Command-Shift-3).
public struct ShortcutConfiguration: Codable, Equatable, Sendable {
    public var keyCode: UInt16 = 20
    public var command = true
    public var shift = true
    public var option = false
    public var control = false

    public init() {}

    public init(keyCode: UInt16, command: Bool = true, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.keyCode = keyCode
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    public static let presets: [(name: String, shortcut: ShortcutConfiguration)] = [
        ("Screenshot — Save", .init()),
        ("Screenshot — Clipboard", .init(keyCode: 20, shift: true, control: true)),
        ("Screenshot — Select Area", .init(keyCode: 21, shift: true)),
        ("Screenshot — Options", .init(keyCode: 23, shift: true)),
        ("Copy", .init(keyCode: 8)), ("Paste", .init(keyCode: 9)),
        ("Undo", .init(keyCode: 6)), ("Redo", .init(keyCode: 6, shift: true)),
        ("Spotlight", .init(keyCode: 49)), ("Switch App", .init(keyCode: 48)),
        ("Mission Control", .init(keyCode: 126, command: false, control: true)),
        ("App Exposé", .init(keyCode: 125, command: false, control: true)),
        ("Desktop Left", .init(keyCode: 123, command: false, control: true)),
        ("Desktop Right", .init(keyCode: 124, command: false, control: true)),
        ("Show Desktop", .init(keyCode: 103, command: false))
    ]

    public var displayName: String {
        let modifiers = (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "")
        return modifiers + (Self.keys.first { $0.code == keyCode }?.label ?? "Unknown Key")
    }

    public static let keys: [(code: UInt16, label: String)] = [
        (0, "A"), (11, "B"), (8, "C"), (2, "D"), (14, "E"), (3, "F"), (5, "G"),
        (4, "H"), (34, "I"), (38, "J"), (40, "K"), (37, "L"), (46, "M"), (45, "N"),
        (31, "O"), (35, "P"), (12, "Q"), (15, "R"), (1, "S"), (17, "T"), (32, "U"),
        (9, "V"), (13, "W"), (7, "X"), (16, "Y"), (6, "Z"),
        (29, "0"), (18, "1"), (19, "2"), (20, "3"), (21, "4"), (23, "5"),
        (22, "6"), (26, "7"), (28, "8"), (25, "9"), (49, "Space"), (36, "Return"), (48, "Tab"), (51, "Delete"), (53, "Escape"),
        (24, "="), (27, "-"), (30, "]"), (33, "["), (39, "’"), (41, ";"),
        (43, ","), (44, "/"), (47, "."), (50, "`"),
        (123, "Left Arrow"), (124, "Right Arrow"), (125, "Down Arrow"), (126, "Up Arrow"),
        (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"), (96, "F5"), (97, "F6"),
        (98, "F7"), (100, "F8"), (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12")
    ]

    public var isValid: Bool {
        Self.keys.contains { $0.code == keyCode } &&
            (command || shift || option || control || [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111].contains(keyCode))
    }
}

/// Positive means up on a side edge and right on the bottom edge.
public struct DirectionalShortcuts: Codable, Equatable, Sendable {
    public var enabled = false
    public var positive = ShortcutConfiguration()
    public var negative = ShortcutConfiguration()

    public init() {}
}
