import Foundation

// MARK: - 绝对不能删除的系统路径（全路径匹配，最终安全网）
/// 这些路径即使被误判为「残留」，也绝对不能删除
let neverDeletePaths: Set<String> = {
    let home = NSHomeDirectory()
    return [
        "\(home)/Library/Application Support/MobileSync",
        "\(home)/Library/Application Support/MobileSync/Backup",
        "\(home)/Library/Application Support/AddressBook",
        "\(home)/Library/Application Support/iCloud",
        "\(home)/Library/Application Support/CloudDocs",
        "\(home)/Library/Application Support/CallHistoryDB",
        "\(home)/Library/Application Support/CallHistoryTransactions",
        "\(home)/Library/Application Support/Messages",
        "\(home)/Library/Application Support/Maps",
        "\(home)/Library/Application Support/Reminders",
        "\(home)/Library/Application Support/Notes",
        "\(home)/Library/Application Support/Photos",
        "\(home)/Library/Application Support/PhotoBooth",
        "\(home)/Library/Application Support/FaceTime",
        "\(home)/Library/Application Support/Stocks",
        "\(home)/Library/Application Support/Weather",
        "\(home)/Library/Application Support/Health",
        "\(home)/Library/Preferences/com.apple.AppStore.plist",
        "\(home)/Library/Preferences/com.apple.Safari.plist",
    ]
}()

// MARK: - 扫描位置
enum ScanLocation: String, CaseIterable, Identifiable {
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case logs = "Logs"
    case preferences = "Preferences"
    case webKit = "WebKit"
    case savedState = "Saved Application State"
    
    var id: String { rawValue }
    
    var path: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent(rawValue)
            .path
    }
    
    var icon: String {
        switch self {
        case .applicationSupport: return "folder"
        case .caches: return "archivebox"
        case .logs: return "doc.text"
        case .preferences: return "gearshape"
        case .webKit: return "globe"
        case .savedState: return "clock"
        }
    }
    
    /// 该位置的风险说明
    var riskDescription: String {
        switch self {
        case .applicationSupport: return "应用数据目录，删除会导致应用设置丢失"
        case .caches: return "缓存目录，删除后下次使用会重新生成"
        case .logs: return "日志目录，删除不影响应用运行"
        case .preferences: return "偏好设置，删除后应用会恢复默认设置"
        case .webKit: return "网页缓存，删除后浏览器会重新加载"
        case .savedState: return "窗口状态，删除不影响使用"
        }
    }
}

// MARK: - 孤儿条目
struct OrphanItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let location: ScanLocation
    let size: Int64  // bytes
    let isDirectory: Bool
    
    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: size)
    }
    
    var categoryIcon: String {
        if name.hasPrefix("com.") || name.hasPrefix("io.") || name.hasPrefix("org.") || name.hasPrefix("cn.") || name.hasPrefix("dev.") {
            return "curlybraces"
        }
        return "app"
    }
    
    /// 是否为系统路径（安全网保护）
    var isProtectedPath: Bool {
        neverDeletePaths.contains(path)
    }
}

// MARK: - 扫描状态
enum ScanState: Equatable {
    case idle
    case scanning(progress: String)
    case complete(found: Int, totalSize: Int64)
    case error(String)
}

// MARK: - 清理状态
enum CleanState: Equatable {
    case idle
    case cleaning(progress: String)
    case complete(deleted: Int, freedSize: Int64)
    case partial(deleted: Int, failed: [(String, String)], protected: [String])
    case error(String)
    
    static func == (lhs: CleanState, rhs: CleanState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.cleaning, .cleaning): return true
        case (.complete(let a, _), .complete(let b, _)): return a == b
        case (.partial(let a, _, _), .partial(let b, _, _)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - 已知系统/Apple 目录前缀（跳过）
let systemPrefixes: Set<String> = [
    "com.apple.", "apple",
]

// 已知系统目录名（非第三方应用）
let systemDirNames: Set<String> = [
    // === Apple 系统服务 ===
    "com.apple", "xcode", "icloud", "clouddocs", "addressbook",
    "callhistory", "callhistorydb", "callhistorytransactions", "calendar",
    "containers", "coredata", "diskimages", "facetime",
    "maps", "messages", "music", "notes", "photos", "printers",
    "reminders", "safari", "stocks", "voicetrigger", "mobilesync",
    "askpermission", "animoji", "automator", "crashreporter",
    "differentialprivacy", "fileprovider", "sesstorage", "systempreferences",
    "knowledge", "locationaccessstored", "networkserviceproxy",
    "openscreen", "homeenergyd", "icdd", "rtk", "gk", "iii", "spotlight",
    "mobilemeaccounts", "byhost",
    "discrecording", "photosupgrade", "appanalytics", "coresimulator",
    "diagnosticreports", "passkit", "familycircled", "gamekit",
    "jetpackcache", "mbuseragent", "cloudkit", "com.electron.ollama",
    "appstore", "assistivetouchd", "audiocomponent", "authkit",
    "backgroundtaskmanagement", "bluetooth", "classkit",
    "coregraphics", "coresymbolication",
    "swift-build", "flutter_engine", "libcachedimagedata",
    "google-sdks-events", "minilauncher", "sentrycrash",
    "profiles", "statsig-cache", "io.sentry", "geoservices",
    "askpermissiond", "nextjs-nodejs", "netlify", "astro", "no_backup",
    "swift", "accounts", "appstore", "assetlocator", "audiounitregistrations",
    "autocorrection", "backgroundassets", "biome", "calendarsubscriptions",
    "classroom", "cloudpairing", "com.apple.ml", "contacts",
    "corespeech", "dataaccess", "dataware", "devicemanagement",
    "downloads", "extensions", "feedbackassistant", "filecoordinator",
    "gamecontroller", "genealogy", "graphicservices", "identityservices",
    "intelligenceplatform", "kernel", "keyboardservices", "languagemodeling",
    "localization", "loginwindow", "mediaremote", "mediaanalysis",
    "mediatoolbox", "memory", "metadata", "mobileasset",
    "multitouch", "naturalvision", "networking", "notificationcenter",
    "osanalytics", "parsecfbf", "peoplepicker", "personas",
    "phoneformfactor", "powerlog", "print", "proactiveengine",
    "proximity", "quicklook", "receives", "runningboard",
    "screentime", "secureelement", "security", "semantic",
    "sharing", "signpost", "siri", "sirisuggestions",
    "smartcard", "softwareupdate", "speech", "speechrecognition",
    "spotlightindex", "storage", "suggestions", "symbolication",
    "synceddefaults", "symptoms", "systempolicy", "telemetry",
    "textcompletion", "textinput", "timeline", "touchbar",
    "typology", "universalaccess", "usernotifications",
    "video", "voiceover", "voicememos", "wifi", "windowmanager",
    
    // === 第三方系统级服务 ===
    "com.tencent.inputmethod.wetype", "com.tencent.wetype.installerapp",
    "com.tencent.dtmpupdateserver",
    "com.microsoft.vscode.shipit", "com.microsoft.edgemac",
    "com.google.keystone", "com.google.googleupdater", "com.microsoft.edgeupdater",
]

// 保留的目录（属于用户自己的工具或已知安全项）
let alwaysKeep: Set<String> = [
    "baoyu-skills", "lark-cli", "pi-web-tauri", "wechattweak",
    "new-agent", "chrome-devtools-mcp",
]
