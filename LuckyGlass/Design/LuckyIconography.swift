import SwiftUI

/// The app's glyph vocabulary.
///
/// The original uses lucide icons imported per screen; SF Symbols are the native equivalent and
/// they also give the tab bar and the toolbars their correct optical alignment. Every name here is
/// a symbol that has existed since iOS 16 or earlier — a missing symbol renders as a blank box, and
/// the endpoint browser draws 45 of them at once.
enum LuckySymbol {
    // MARK: - Sections

    static let services = "square.stack.3d.up"
    static let docker = "cube.transparent"
    static let monitor = "waveform.path.ecg"
    static let debugger = "curlybraces.square"
    static let settings = "gearshape"
    static let logs = "text.alignleft"
    static let login = "person.badge.key"

    // MARK: - Recurring actions

    static let refresh = "arrow.clockwise"
    static let copy = "doc.on.doc"
    static let start = "play.fill"
    static let stop = "stop.fill"
    static let restart = "arrow.triangle.2.circlepath"
    static let delete = "trash"
    static let edit = "square.and.pencil"
    static let add = "plus"
    static let send = "paperplane.fill"
    static let download = "arrow.down.circle"
    static let upload = "arrow.up.circle"
    static let search = "magnifyingglass"
    static let filter = "line.3.horizontal.decrease.circle"
    static let expand = "chevron.down"
    static let external = "arrow.up.right.square"
    static let danger = "exclamationmark.triangle.fill"
    static let clock = "clock"
    static let key = "key.fill"
    static let network = "network"
    static let memory = "memorychip"
    static let cpu = "cpu"
    static let disk = "internaldrive"
    static let uptime = "clock.arrow.circlepath"

    // MARK: - Service kinds

    static func kind(_ kind: LuckyServiceKind) -> String {
        switch kind {
        case .webservice: "network"
        case .ddns: "globe.asia.australia"
        case .docker: "cube.transparent"
        case .ssl: "lock.shield"
        }
    }

    // MARK: - Registry modules

    /// One glyph per module key in `LuckyEndpoints.json`. All 45 are listed explicitly rather than
    /// pattern-matched: `stunrulelist_lite` and `portforwards_lite` would otherwise collide with
    /// their full-list siblings, and a wrong-but-plausible glyph is worse than a generic one.
    private static let moduleSymbols: [String: String] = [
        "update": "arrow.down.circle",
        "storagemanagement": "internaldrive",
        "login": "person.badge.key",
        "third": "puzzlepiece.extension",
        "thirdPartyAuthManager": "person.crop.circle.badge.checkmark",
        "ddns": "globe.asia.australia",
        "portforward": "arrow.left.arrow.right",
        "portforwards_lite": "list.dash",
        "portforwards": "list.bullet",
        "webservice": "network",
        "restoreconfigureconfirm": "arrow.counterclockwise.circle",
        "baseconfigure": "slider.horizontal.3",
        "base": "shippingbox",
        "cron": "clock.arrow.circlepath",
        "modules": "square.grid.2x2",
        "logs": "text.alignleft",
        "twofapassword": "key.fill",
        "iconlib": "photo.on.rectangle.angled",
        "logout": "rectangle.portrait.and.arrow.right",
        "wol": "power",
        "netinterfaces": "cable.connector",
        "info": "info.circle",
        "status": "waveform.path.ecg",
        "reboot_program": "arrow.triangle.2.circlepath",
        "cloudflared": "cloud",
        "coraza": "shield.lefthalf.filled",
        "ddnstasklist": "list.bullet.rectangle",
        "dlnaservice": "airplayvideo",
        "docker": "cube.transparent",
        "frp": "point.3.connected.trianglepath.dotted",
        "ftpserver": "server.rack",
        "ipregtest": "testtube.2",
        "ipfliter": "hand.raised",
        "ipdb": "tablecells",
        "lucky": "sparkles",
        "oauth": "person.badge.shield.checkmark",
        "rclone": "externaldrive.badge.icloud",
        "ssl": "lock.shield",
        "stun": "antenna.radiowaves.left.and.right",
        "stunrule": "dot.radiowaves.left.and.right",
        "stunrulelist": "list.bullet.below.rectangle",
        "stunrulelist_lite": "list.dash",
        "v2l": "v.circle",
        "webdav": "folder.badge.person.crop",
        "webterminal": "terminal",
    ]

    /// Falls back to a neutral glyph so a module added by a newer Lucky build still draws.
    static func module(_ key: String) -> String {
        moduleSymbols[key] ?? "circle.grid.2x2"
    }

    // MARK: - Solid Glyph Mapping

    /// Maps wireframe and hollow glyphs to their bold, solid (.fill) equivalents for modern, frameless presentation.
    static func solid(_ symbol: String) -> String {
        switch symbol {
        case "cube.transparent": return "cube.fill"
        case "globe.asia.australia": return "globe.asia.australia.fill"
        case "lock.shield": return "lock.shield.fill"
        case "checkmark.shield": return "checkmark.shield.fill"
        case "cloud": return "cloud.fill"
        case "shippingbox": return "shippingbox.fill"
        case "internaldrive": return "internaldrive.fill"
        case "cpu": return "cpu.fill"
        case "memorychip": return "memorychip.fill"
        case "gearshape": return "gearshape.fill"
        case "gearshape.2": return "gearshape.2.fill"
        case "doc.text": return "doc.text.fill"
        case "curlybraces.square": return "wrench.and.screwdriver.fill"
        case "person.crop.circle": return "person.crop.circle.fill"
        case "person.badge.key": return "person.badge.key.fill"
        case "square.grid.2x2": return "square.grid.2x2.fill"
        case "folder": return "folder.fill"
        case "archivebox": return "archivebox.fill"
        case "tray.and.arrow.down": return "tray.and.arrow.down.fill"
        case "stop.circle": return "stop.circle.fill"
        case "arrow.down.circle": return "arrow.down.circle.fill"
        case "arrow.up.circle": return "arrow.up.circle.fill"
        case "point.3.connected.trianglepath.dotted": return "point.3.filled.connected.trianglepath.dotted"
        case "trash": return "trash.fill"
        case "shield.lefthalf.filled": return "shield.fill"
        case "externaldrive": return "externaldrive.fill"
        case "tag": return "tag.fill"
        case "lock": return "lock.fill"
        case "person": return "person.fill"
        case "wrench.and.screwdriver": return "wrench.and.screwdriver.fill"
        case "exclamationmark.shield": return "exclamationmark.shield.fill"
        case "info.circle": return "info.circle.fill"
        case "checkmark.circle": return "checkmark.circle.fill"
        case "magnifyingglass.circle": return "magnifyingglass.circle.fill"
        case "hammer": return "hammer.fill"
        case "doc.on.doc": return "doc.on.doc.fill"
        case "doc.on.clipboard": return "doc.on.clipboard.fill"
        case "eye": return "eye.fill"
        case "eye.slash": return "eye.slash.fill"
        default:
            return symbol
        }
    }
}

/// A pure solid symbol rendered directly without an enclosing plate or outer box.
struct LuckyIconTile: View {
    var symbol: String
    var size: CGFloat = 38
    var glyph: CGFloat = 18
    var tone: LuckyTone? = nil
    var role: LuckyIconRole? = nil
    var filled: Bool = false

    var body: some View {
        LuckyFunctionIcon(symbol: symbol, size: size, glyph: glyph,
                          color: tone?.tint ?? (role ?? LuckyIconRole.symbol(symbol)).color,
                          filled: filled)
    }
}

/// The colour-based variant is used by controls whose colour is supplied directly instead of via
/// `LuckyTone` (for example container actions derived from their current state).
/// Renders clean solid SF Symbols without an enclosing box/frame.
struct LuckyFunctionIcon: View {
    var symbol: String
    var size: CGFloat = 38
    var glyph: CGFloat = 18
    var color: Color = LuckyIconRole.neutral.color
    var filled: Bool = false

    private var solidSymbol: String {
        LuckySymbol.solid(symbol)
    }

    private var opticalGlyphSize: CGFloat {
        max(glyph, size * 0.62)
    }

    var body: some View {
        Image(systemName: solidSymbol)
            .font(.system(size: opticalGlyphSize, weight: .bold))
            .foregroundStyle(color)
            .frame(width: size, height: size, alignment: .center)
            .accessibilityHidden(true)
    }
}

/// Presentation metadata for the three tunnel kinds. Function colours live in `LuckyIconRole`.
extension TunnelKind {
    var symbol: String {
        switch self {
        case .stun: "point.3.filled.connected.trianglepath.dotted"
        case .cloudflared: "cloud"
        case .frp: "point.3.connected.trianglepath.dotted"
        }
    }

    /// `detail` on the tile.
    var detail: String {
        switch self {
        case .stun: "穿透规则与公网地址"
        case .cloudflared: "隧道与域名路由"
        case .frp: "客户端、服务端与代理"
        }
    }
}
