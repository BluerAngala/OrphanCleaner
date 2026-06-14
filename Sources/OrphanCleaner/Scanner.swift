import Foundation
import AppKit

// MARK: - 已安装应用收集器
struct InstalledAppCollector {

    /// 获取所有已安装应用的名称集合(用于交叉比对)
    static func collect() -> InstalledAppIndex {
        var index = InstalledAppIndex()
        let fm = FileManager.default
        let appDirs = [
            "/Applications",
            "\(NSHomeDirectory())/Applications",
            "/System/Applications"
        ]

        // 1. 扫描 .app 目录
        for dir in appDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let name = String(item.dropLast(4))
                index.addApp(name: name, bundleID: nil)

                let plistPath = "\(dir)/\(item)/Contents/Info.plist"
                if let bid = readBundleID(from: plistPath) {
                    index.addApp(name: name, bundleID: bid)
                }
            }
        }

        // 2. Homebrew casks
        if let result = try? Process.run("/opt/homebrew/bin/brew", arguments: ["list", "--cask"]) {
            for line in result.components(separatedBy: .newlines) where !line.isEmpty {
                let cask = line.trimmingCharacters(in: .whitespaces)
                index.addApp(name: cask, bundleID: nil)
            }
        }

        // 3. Homebrew packages
        if let result = try? Process.run("/opt/homebrew/bin/brew", arguments: ["list"]) {
            for line in result.components(separatedBy: .newlines) where !line.isEmpty {
                let pkg = line.trimmingCharacters(in: .whitespaces)
                index.addFormula(name: pkg)
            }
        }

        // 4. 正在运行的进程
        if let result = try? Process.run("/bin/ps", arguments: ["ax", "-o", "comm="]) {
            for line in result.components(separatedBy: .newlines) {
                let process = (line as NSString).lastPathComponent
                    .lowercased()
                    .replacingOccurrences(of: ".app", with: "")
                if !process.isEmpty && !process.contains("/") {
                    index.addProcess(name: process)
                }
            }
        }

        return index
    }

    private static func readBundleID(from plistPath: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let bid = dict["CFBundleIdentifier"] as? String
        else { return nil }
        return bid
    }
}

// MARK: - 已安装应用索引
struct InstalledAppIndex {
    /// 原始 bundle IDs(小写)
    private(set) var bundleIDs: Set<String> = []
    /// 原始应用名(保留原始大小写)
    private(set) var appNames: [String] = []
    /// bundle ID 的每个部分(用于部分匹配)
    private var bundleIDTokens: Set<String> = []
    /// 应用名的所有单词(用于 token 匹配)
    private var appNameTokens: Set<String> = []
    /// 所有 clean key(去空格、连字符、下划线)
    private var cleanKeys: Set<String> = []
    /// 所有 bundle ID 的连续双元组(用于模糊匹配)
    private var bundleIDBigrams: Set<String> = []

    mutating func addApp(name: String, bundleID: String?) {
        let lowerName = name.lowercased()
        appNames.append(name)

        // clean key
        let clean = lowerName.cleaned()
        cleanKeys.insert(clean)

        // tokens (按空格拆分)
        for token in lowerName.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" || $0 == "." }) {
            if token.count > 1 {
                appNameTokens.insert(String(token))
            }
        }

        if let bid = bundleID {
            let lowerBid = bid.lowercased()
            bundleIDs.insert(lowerBid)
            cleanKeys.insert(lowerBid.cleaned())

            // bundle ID tokens
            let parts = lowerBid.split(separator: ".")
            for part in parts where part.count > 1 {
                bundleIDTokens.insert(String(part))
            }

            // bundle ID bigrams (consecutive pairs)
            if parts.count >= 2 {
                for i in 0..<(parts.count - 1) {
                    bundleIDBigrams.insert("\(parts[i]).\(parts[i+1])")
                }
            }
        }
    }

    mutating func addFormula(name: String) {
        let lower = name.lowercased()
        cleanKeys.insert(lower.cleaned())
        if lower.count > 1 {
            appNameTokens.insert(lower)
        }
    }

    mutating func addProcess(name: String) {
        let lower = name.lowercased().cleaned()
        cleanKeys.insert(lower)
        if lower.count > 2 {
            appNameTokens.insert(lower)
        }
    }

    /// 判断目录名是否属于某个已安装应用(安全优先:宁可漏报,不可误报)
    func belongsToInstalled(name: String) -> Bool {
        let lower = name.lowercased()
        let cleaned = lower.cleaned()

        // ==== 策略 1: 精确匹配 ====
        if cleanKeys.contains(cleaned) { return true }
        if cleanKeys.contains(lower) { return true }
        if bundleIDs.contains(lower) { return true }

        // ==== 策略 2: Token 匹配(目录名是已安装应用的某个单词) ====
        // 例如 "Code" → "Visual Studio Code" 中的 "code"
        // 例如 "Google" → "Google Chrome" 中的 "google"
        // 但只匹配长度 > 2 的 token,避免 "a", "an", "to" 等误报
        if lower.count > 2 && appNameTokens.contains(lower) { return true }

        // ==== 策略 3: 目录的 token 是否出现在已安装应用的 token 中 ====
        let dirTokens = lower.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" || $0 == "." })
        for token in dirTokens where token.count > 2 {
            if appNameTokens.contains(String(token)) || bundleIDTokens.contains(String(token)) {
                return true
            }
        }

        // ==== 策略 4: Bundle ID 前缀/后缀匹配 ====
        if lower.contains(".") {
            // 4a: 去掉点分后缀(如 .ShipIt)后检查
            let withoutShipIt = stripInstallerSuffix(from: lower)
            if withoutShipIt != lower {
                if belongsToInstalled(name: withoutShipIt) { return true }
            }

            let parts = lower.split(separator: ".")

            // 4b: 检查 bigram 重叠(两个连续的组件匹配)
            if parts.count >= 2 {
                for i in 0..<(parts.count - 1) {
                    let bigram = "\(parts[i]).\(parts[i+1])"
                    if bundleIDBigrams.contains(bigram) { return true }
                }
            }

            // 4c: 检查是否有两个以上组件同时出现在 bundle ID 中
            var matchCount = 0
            for part in parts where part.count > 1 {
                if bundleIDTokens.contains(String(part)) {
                    matchCount += 1
                }
            }
            if matchCount >= 2 { return true }
        }

        // ==== 策略 5: 已安装应用名包含目录名 ====
        // 反过来检查:确保匹配的是有意义的词
        for appName in appNames {
            let appLower = appName.lowercased()
            // 应用名包含目录名作为完整单词
            let appWords = Set(appLower.split(separator: " ").map(String.init))
            if appWords.contains(lower) { return true }

            // 对不带空格的名称:检查是否包含
            let appClean = appLower.cleaned()
            if appClean.contains(cleaned) && cleaned.count > 2 {
                // 避免 "de" in "desktop" 这种误报
                // 确保是完整的"词界"匹配
                if appClean.hasPrefix(cleaned) || appClean.hasSuffix(cleaned) {
                    return true
                }
            }
        }

        // ==== 策略 6: 已知常见别名(硬编码安全网) ====
        let manualMapping: [String: Set<String>] = [
            "code": ["visual studio code", "vscode"],
            "google": ["google chrome"],
            "microsoft": ["microsoft edge"],
            "zed": ["zed"],
            "trae": ["trae cn", "trae solo"],
            "docker desktop": ["docker"],
            "cherrystudiopi": ["cherry studio"],
            "cherrystudio": ["cherry studio"],
            "siyuan": ["siyuan"],
            "hbuilder x": ["hbuilderx"],
        ]
        if let matches = manualMapping[cleaned] {
            for match in matches {
                if cleanKeys.contains(where: { $0.contains(match) }) { return true }
            }
        }

        return false
    }

    /// 去掉安装器/更新器后缀
    private func stripInstallerSuffix(from name: String) -> String {
        let suffixes = [".shipit", "-updater", "_updater", ".updater", "-shipit", ".shipit", "-update", "shipit"]
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                return String(name.dropLast(suffix.count))
            }
        }
        return name
    }
}

// MARK: - String 扩展
extension String {
    func cleaned() -> String {
        return self.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
}

extension Process {
    static func run(_ path: String, arguments: [String]) throws -> String {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        proc.standardOutput = pipe
        proc.standardError = pipe

        // Read pipe data on a background thread while process runs,
        // preventing pipe-buffer deadlock when output exceeds 64KB.
        let group = DispatchGroup()
        var outputData = Data()
        group.enter()
        DispatchQueue.global().async {
            outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        try proc.run()
        proc.waitUntilExit()
        group.wait()

        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

// MARK: - 孤儿扫描器
struct OrphanScanner {

    static func scan(installed: InstalledAppIndex, includeEmptyDirs: Bool = false, progress: ((String) -> Void)? = nil) -> [ScanLocation: [OrphanItem]] {
        var results: [ScanLocation: [OrphanItem]] = [:]
        var emptyItems: [OrphanItem] = []

        for location in ScanLocation.scanLocations {
            let locName = location.displayName
            progress?("正在扫描 \(locName)...")
            
            let items: [OrphanItem]
            switch location {
            case .launchAgents, .systemLaunchAgents, .systemLaunchDaemons:
                items = LaunchItemScanner.scan(location: location)
            case .loginItems:
                items = BTMScanner.scan()
            case .finderExtensions:
                items = ExtensionScanner.scan()
            case .disabledCache:
                items = DisabledCacheScanner.scan()
            default:
                items = scanLocation(location, installed: installed, includeEmptyDirs: includeEmptyDirs)
            }
            if includeEmptyDirs {
                // 把空目录抽到虚拟分类
                var normalItems: [OrphanItem] = []
                for item in items {
                    if item.size == 0 {
                        let e = OrphanItem(
                            name: item.name,
                            path: item.path,
                            location: .emptyDirs,
                            size: item.size,
                            isDirectory: item.isDirectory
                        )
                        emptyItems.append(e)
                    } else {
                        normalItems.append(item)
                    }
                }
                results[location] = normalItems
            } else {
                results[location] = items
            }
        }

        if !emptyItems.isEmpty {
            results[.emptyDirs] = emptyItems
        }

        return results
    }

    private static func scanLocation(_ location: ScanLocation, installed: InstalledAppIndex, includeEmptyDirs: Bool = false) -> [OrphanItem] {
        var orphans: [OrphanItem] = []
        let fm = FileManager.default
        let dirPath = location.path

        guard let items = try? fm.contentsOfDirectory(atPath: dirPath) else {
            return []
        }

        for item in items {
            let itemPath = "\(dirPath)/\(item)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: itemPath, isDirectory: &isDir) else { continue }

            // 跳过 Info.plist
            if item == "Info.plist" { continue }

            // 跳过系统/Apple 目录
            if isSystemItem(item) { continue }

            // 检查归属(核心逻辑)
            if installed.belongsToInstalled(name: item) { continue }
            
            // 安全检查：路径是否在不可删除名单中
            if neverDeletePaths.contains(itemPath) { continue }
            
            let size = directorySize(path: itemPath)
            let isEmpty = isDir.boolValue && !hasContent(path: itemPath, fm: fm)
            let shouldShow = size > 4096 || (!isEmpty) || (isEmpty && includeEmptyDirs)
            if shouldShow {
                let orphan = OrphanItem(
                    name: item,
                    path: itemPath,
                    location: location,
                    size: size,
                    isDirectory: isDir.boolValue
                )
                orphans.append(orphan)
            }
        }

        return orphans.sorted { $0.size > $1.size }
    }

    private static func isSystemItem(_ name: String) -> Bool {
        let lower = name.lowercased()
        if systemPrefixes.contains(where: { lower.hasPrefix($0) }) { return true }
        if systemDirNames.contains(lower) { return true }
        if alwaysKeep.contains(lower) { return true }
        if lower.hasPrefix(".") && lower != ".DS_Store" { return true }
        return false
    }

    private static func directorySize(path: String) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            return (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        }

        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
        var total: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let filePath = "\(path)/\(file)"
            if let attrs = try? fm.attributesOfItem(atPath: filePath),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    private static func hasContent(path: String, fm: FileManager) -> Bool {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return false }
        if !isDir.boolValue { return true }
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return false }
        return contents.filter { $0 != ".DS_Store" }.count > 0
    }
}

// MARK: - 启动项扫描器（LaunchAgents / LaunchDaemons）
struct LaunchItemScanner {
    
    static func scan(location: ScanLocation) -> [OrphanItem] {
        let dirPath = location.path
        let fm = FileManager.default
        let uid = getuid()
        
        guard let items = try? fm.contentsOfDirectory(atPath: dirPath) else { return [] }
        
        // 确定 domain
        let domain: LaunchDomain = location == .systemLaunchDaemons ? .system : .user
        
        return items.compactMap { filename -> OrphanItem? in
            guard filename.hasSuffix(".plist") else { return nil }
            let plistPath = "\(dirPath)/\(filename)"
            
            // 系统保护：跳过 Apple 启动项
            if filename.lowercased().hasPrefix("com.apple") { return nil }
            
            // 解析 plist
            guard let label = readPlistKey(plistPath, key: "Label") else { return nil }
            
            // alwaysKeep 白名单
            if alwaysKeep.contains(label.lowercased()) { return nil }
            
            // 提取可执行文件路径
            let execPath = resolveExecutablePath(plistPath)
            
            // ⚠️ 安全网：可执行文件在系统路径下 → 跳过
            if let ep = execPath, systemBinaryPathPrefixes.contains(where: { ep.hasPrefix($0) }) {
                return nil
            }
            
            // ⚠️ 安全网：无法解析可执行路径 → 保守处理，跳过（避免误判）
            if execPath == nil && readPlistKey(plistPath, key: "Program") == nil
                && readPlistArray(plistPath, key: "ProgramArguments") == nil {
                // 没有任何可执行信息，可能是配置类 plist，跳过
                return nil
            }
            
            // 检查可执行文件是否存在
            if execPath != nil && fm.fileExists(atPath: execPath!) { return nil }
            
            // 如果可执行文件是 .app 内嵌的，检查 .app 是否存在
            if let ep = execPath, ep.contains(".app/") {
                let appPath = extractAppPath(from: ep)
                if fm.fileExists(atPath: appPath) { return nil }
            }
            
            // 检查快捷启动 app（如 /Applications/XXX.app --autostart 模式）
            if let ep = execPath, ep.hasPrefix("/Applications/") || ep.hasPrefix("\(NSHomeDirectory())/Applications/") {
                if fm.fileExists(atPath: ep) { return nil }
            }
            
            // 检查 ProgramArguments 第一个参数（可能是 app bundle 路径）
            let args = readPlistArray(plistPath, key: "ProgramArguments")
            if let firstArg = args?.first, firstArg.hasSuffix(".app") || firstArg.contains(".app/") {
                let appPath = firstArg.hasSuffix(".app") ? firstArg : extractAppPath(from: firstArg)
                if fm.fileExists(atPath: appPath) { return nil }
            }
            
            // 孤儿确认
            let plistSize = (try? fm.attributesOfItem(atPath: plistPath)[.size] as? Int64) ?? 0
            let serviceLabel = label
            
            return OrphanItem(
                name: filename.replacingOccurrences(of: ".plist", with: ""),
                path: plistPath,
                location: location,
                size: plistSize,
                isDirectory: false,
                deletionMethod: .launchItem(serviceLabel: serviceLabel, domain: domain)
            )
        }
    }
    
    private static func resolveExecutablePath(_ plistPath: String) -> String? {
        // 优先 ProgramArguments 第一个元素
        if let args = readPlistArray(plistPath, key: "ProgramArguments"), let first = args.first {
            // 如果是 node/python 等解释器，实际目标可能是第二个参数
            let exec = first.hasPrefix("/") ? first : "/usr/bin/\(first)"
            if FileManager.default.fileExists(atPath: exec) && args.count > 1 {
                let target = args[1]
                if target.hasPrefix("/") { return target }
                // 相对路径需要结合 WorkingDirectory
                if let wd = readPlistKey(plistPath, key: "WorkingDirectory") {
                    return "\(wd)/\(target)"
                }
            }
            return first.hasPrefix("/") || first.hasPrefix("~") ? first : nil
        }
        // 其次 Program 键
        if let prog = readPlistKey(plistPath, key: "Program") {
            return prog
        }
        return nil
    }
    
    private static func extractAppPath(from execPath: String) -> String {
        // 从 /path/to/XXX.app/Contents/... 提取 XXX.app 路径
        let comps = execPath.split(separator: "/")
        for (i, comp) in comps.enumerated() where comp.hasSuffix(".app") {
            return "/" + comps[0...i].joined(separator: "/")
        }
        return execPath
    }
    
    private static func readPlistKey(_ path: String, key: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return dict[key] as? String
    }
    
    private static func readPlistArray(_ path: String, key: String) -> [String]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return dict[key] as? [String]
    }
}

// MARK: - 登录项扫描器（sfltool dumpbtm）
struct BTMScanner {
    
    static func scan() -> [OrphanItem] {
        guard let output = try? Process.run("/usr/bin/sfltool", arguments: ["dumpbtm"]) else {
            return []
        }
        
        let fm = FileManager.default
        var orphans: [OrphanItem] = []
        var currentName: String = ""
        var currentType: String = ""
        var currentURL: String = ""
        var currentIdentifier: String = ""
        var currentDisposition: String = ""
        
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("Name:") {
                currentName = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if currentName == "(null)" { currentName = "" }
            } else if trimmed.hasPrefix("Type:") {
                currentType = trimmed
            } else if trimmed.hasPrefix("URL:") {
                currentURL = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                if currentURL == "(null)" { currentURL = "" }
            } else if trimmed.hasPrefix("Identifier:") {
                currentIdentifier = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Disposition:") {
                currentDisposition = trimmed
            } else if trimmed.hasPrefix("Generation:") && !currentIdentifier.isEmpty {
                // 条目结束，判断是否孤儿
                defer {
                    currentName = ""
                    currentURL = ""
                    currentIdentifier = ""
                    currentType = ""
                    currentDisposition = ""
                }
                
                // 跳过系统条目
                if currentIdentifier.lowercased().hasPrefix("com.apple") { continue }
                if currentDisposition.contains("not notified") { continue } // 已标记但未实际注册
                
                // 跳过 still-alive 正在运行中的
                if currentDisposition.contains("enabled") && currentDisposition.contains("notified") && !currentDisposition.contains("disallowed") {
                    continue
                }
                
                // 检查 URL 目标是否存在
                var targetExists = false
                if currentURL.hasPrefix("file://") {
                    let filePath = currentURL.replacingOccurrences(of: "file://", with: "")
                        .removingPercentEncoding ?? currentURL
                    targetExists = fm.fileExists(atPath: filePath)
                } else if !currentURL.isEmpty {
                    // 绝对路径
                    targetExists = fm.fileExists(atPath: currentURL)
                }
                
                if !targetExists && !currentIdentifier.isEmpty {
                    let displayName = currentName.isEmpty ? currentIdentifier : currentName
                    orphans.append(OrphanItem(
                        name: displayName,
                        path: currentURL.isEmpty ? currentIdentifier : currentURL,
                        location: .loginItems,
                        size: 0,
                        isDirectory: false,
                        deletionMethod: .btmReset
                    ))
                }
            }
        }
        
        return orphans
    }
}

// MARK: - 扩展扫描器（pluginkit）
struct ExtensionScanner {
    
    static func scan() -> [OrphanItem] {
        guard let output = try? Process.run("/usr/bin/pluginkit", arguments: ["-m", "-v", "-p", "com.apple.FinderSync"]) else {
            return []
        }
        
        let fm = FileManager.default
        var orphans: [OrphanItem] = []
        
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // 格式: [+?-] identifier(version)  UUID  date  /path/to/PlugIn.appex
            // 跳过系统扩展
            if trimmed.contains("com.apple") { continue }
            
            // 提取路径（最后一个以 / 开头的字段）
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let pathPart = parts.last(where: { $0.hasPrefix("/") }) else { continue }
            
            // 检查插件文件是否存在
            if fm.fileExists(atPath: pathPart) { continue }
            
            // 提取标识符
            let identPart = parts.first ?? ""
            let ident = identPart.replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "?", with: "")
            
            // 提取版本号
            var name = ident
            if let parenRange = ident.range(of: "(") {
                name = String(ident[..<parenRange.lowerBound])
            }
            
            orphans.append(OrphanItem(
                name: name,
                path: pathPart,
                location: .finderExtensions,
                size: 0,
                isDirectory: false,
                deletionMethod: .extensionPlugin(pluginPath: pathPart)
            ))
        }
        
        return orphans
    }
}

// MARK: - 服务缓存扫描器（disabled.plist）
struct DisabledCacheScanner {
    
    static func scan() -> [OrphanItem] {
        var orphans: [OrphanItem] = []
        let home = NSHomeDirectory()
        
        // 系统级 disabled.plist
        let sysPath = "/var/db/com.apple.xpc.launchd/disabled.plist"
        if let sysOrphans = scanDisabledPlist(sysPath, domain: .system, home: home) {
            orphans.append(contentsOf: sysOrphans)
        }
        
        // 用户级 disabled.plist
        let userPath = "\(home)/Library/Preferences/com.apple.xpc.launchd/disabled.\(getuid()).plist"
        if let userOrphans = scanDisabledPlist(userPath, domain: .user, home: home) {
            orphans.append(contentsOf: userOrphans)
        }
        
        return orphans
    }
    
    private static func scanDisabledPlist(_ plistPath: String, domain: LaunchDomain, home: String) -> [OrphanItem]? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: plistPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        
        var orphans: [OrphanItem] = []
        
        for (label, _) in dict {
            // 跳过 Apple 系统条目
            if label.lowercased().hasPrefix("com.apple") { continue }
            
            // 检查对应 plist 是否存在
            let launchDirs = domain == .system
                ? ["/Library/LaunchDaemons", "/Library/LaunchAgents"]
                : ["\(home)/Library/LaunchAgents"]
            
            let plistExists = launchDirs.contains { dir in
                fm.fileExists(atPath: "\(dir)/\(label).plist")
            }
            
            if !plistExists {
                orphans.append(OrphanItem(
                    name: label,
                    path: plistPath,
                    location: .disabledCache,
                    size: 0,
                    isDirectory: false,
                    deletionMethod: .disabledCache(plistPath: plistPath, entryKey: label)
                ))
            }
        }
        
        return orphans
    }
}
