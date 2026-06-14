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
    // ── ~/Library 文件残留 ──
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case logs = "Logs"
    case preferences = "Preferences"
    case webKit = "WebKit"
    case savedState = "Saved Application State"
    
    // ── 启动项残留（LaunchAgents / LaunchDaemons）──
    case launchAgents = "LaunchAgents"
    case systemLaunchAgents = "/Library/LaunchAgents"
    case systemLaunchDaemons = "/Library/LaunchDaemons"
    
    // ── 系统注册表残留（CLI 工具采集）──
    case loginItems = "loginItems"
    case finderExtensions = "finderExtensions"
    case disabledCache = "disabledCache"
    
    /// 虚拟分类：存放各位置扫描出的空目录
    case emptyDirs = ""
    
    /// 文件扫描位置
    static let fileScanLocations: [ScanLocation] = [
        .applicationSupport, .caches, .logs, .preferences, .webKit, .savedState
    ]
    
    /// 启动项扫描位置
    static let launchScanLocations: [ScanLocation] = [
        .launchAgents, .systemLaunchAgents, .systemLaunchDaemons
    ]
    
    /// 注册表扫描位置（CLI 工具）
    static let registryScanLocations: [ScanLocation] = [
        .loginItems, .finderExtensions, .disabledCache
    ]
    
    /// 全部扫描位置
    static let scanLocations: [ScanLocation] =
        fileScanLocations + launchScanLocations + registryScanLocations
    
    var id: String {
        switch self {
        case .emptyDirs: return "__empty_dirs__"
        default: return rawValue
        }
    }
    
    /// 中文显示名
    /// 是否为注册表类型（非文件/目录残留）
    var isRegistryType: Bool {
        switch self {
        case .loginItems, .finderExtensions, .disabledCache: return true
        default: return false
        }
    }
    
    var displayName: String {
        switch self {
        case .applicationSupport: return "应用支持"
        case .caches: return "缓存"
        case .logs: return "日志"
        case .preferences: return "偏好设置"
        case .webKit: return "网页缓存"
        case .savedState: return "窗口状态"
        case .launchAgents: return "用户启动项"
        case .systemLaunchAgents: return "系统启动项"
        case .systemLaunchDaemons: return "系统守护进程"
        case .loginItems: return "登录项残留"
        case .finderExtensions: return "扩展残留"
        case .disabledCache: return "服务缓存残留"
        case .emptyDirs: return "空目录"
        }
    }
    
    var path: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .emptyDirs: return ""
        case .applicationSupport: return "\(home)/Library/Application Support"
        case .caches: return "\(home)/Library/Caches"
        case .logs: return "\(home)/Library/Logs"
        case .preferences: return "\(home)/Library/Preferences"
        case .webKit: return "\(home)/Library/WebKit"
        case .savedState: return "\(home)/Library/Saved Application State"
        case .launchAgents: return "\(home)/Library/LaunchAgents"
        case .systemLaunchAgents: return "/Library/LaunchAgents"
        case .systemLaunchDaemons: return "/Library/LaunchDaemons"
        case .loginItems, .finderExtensions, .disabledCache: return ""
        }
    }
    
    var icon: String {
        switch self {
        case .applicationSupport: return "folder"
        case .caches: return "archivebox"
        case .logs: return "doc.text"
        case .preferences: return "gearshape"
        case .webKit: return "globe"
        case .savedState: return "clock"
        case .launchAgents: return "arrow.right.circle"
        case .systemLaunchAgents: return "arrow.right.circle.fill"
        case .systemLaunchDaemons: return "shield"
        case .loginItems: return "person.badge.key"
        case .finderExtensions: return "puzzlepiece.extension"
        case .disabledCache: return "memorychip"
        case .emptyDirs: return "folder"
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
        case .launchAgents: return "用户登录时自动启动的服务配置，删除 plist 即可"
        case .systemLaunchAgents: return "全局登录启动项，需 sudo 删除"
        case .systemLaunchDaemons: return "系统级守护进程，需 sudo 删除"
        case .loginItems: return "登录项注册表残留，需 sfltool 清理"
        case .finderExtensions: return "Finder 扩展注册残留，需 pluginkit 清理"
        case .disabledCache: return "launchctl 禁用状态缓存，不影响系统运行"
        case .emptyDirs: return "完全空置的目录，删除没有影响"
        }
    }
}

// MARK: - 删除策略
enum DeletionMethod {
    /// 常规：移到废纸篓
    case trash
    /// 启动项：先 launchctl bootout 再删除 plist
    case launchItem(serviceLabel: String, domain: LaunchDomain)
    /// Finder 扩展：pluginkit -r 注销
    case extensionPlugin(pluginPath: String)
    /// 登录项：sfltool resetbtm 重置数据库
    case btmReset
    /// disabled 缓存：PlistBuddy 删除条目
    case disabledCache(plistPath: String, entryKey: String)
    /// 不可自动清理，仅提示
    case manualOnly(reason: String)
}

enum LaunchDomain {
    case user   // gui/UID
    case system // system
}

// MARK: - 孤儿条目
struct OrphanItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let location: ScanLocation
    let size: Int64  // bytes
    let isDirectory: Bool
    /// 删除策略（nil 则默认 trash）
    let deletionMethod: DeletionMethod?
    
    init(name: String, path: String, location: ScanLocation, size: Int64, isDirectory: Bool, deletionMethod: DeletionMethod? = nil) {
        self.name = name
        self.path = path
        self.location = location
        self.size = size
        self.isDirectory = isDirectory
        self.deletionMethod = deletionMethod
    }
    
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
    "diagnosticreports", "passkit", "familycircle", "familycircled", "gamekit",
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
    
    // === Launch 系统服务 ===
    "com.apple.mdmclient.daemon.runatboot", "com.apple.ftpd", "com.apple.bootpd",
    "com.apple.ftp-proxy", "com.apple.CSCSupportd", "com.apple.FolderActionsDispatcher",
    "com.apple.Siri.agent", "com.apple.ManagedClientAgent.enrollagent",
    "com.apple.appleseed.seedusaged.postinstall", "com.apple.ScriptMenuApp",
    "com.apple.ManagedClient.startup", "com.apple.ManagedClient",
    "com.apple.loginitems", "com.apple.backgroundtaskmanagementagent",
]

// 保留的目录（属于用户自己的工具或已知安全项）
let alwaysKeep: Set<String> = [
    "baoyu-skills", "lark-cli", "pi-web-tauri", "wechattweak",
    "new-agent", "chrome-devtools-mcp",
    // 常见合法启动项（正在使用中的）
    "com.cc-agent", "homebrew.mxcl.postgresql@16", "homebrew.mxcl.redis",
    "com.github.domt4.homebrew-autoupdate",
]

// ⚠️ Launch 级别不可触碰的白名单 label
let neverUnloadLabels: Set<String> = [
    "com.apple.",
]

/// 系统二进制路径前缀（这些路径下的可执行文件标记为系统级，不可清理）
let systemBinaryPathPrefixes: Set<String> = [
    "/System/Library/", "/usr/libexec/", "/usr/sbin/", "/sbin/",
    "/usr/bin/", "/bin/", "/Library/Apple/",
]
