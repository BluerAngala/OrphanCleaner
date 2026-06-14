import Foundation

// MARK: - 清理服务
struct CleanerService {
    
    /// 删除指定条目（含安全网保护）
    /// - Returns: (成功删除数, 释放大小, 失败列表, 被保护路径列表)
    static func clean(_ items: [OrphanItem], progress: @escaping (String) -> Void) -> (deleted: Int, freed: Int64, failed: [(String, String)], protected: [String]) {
        var deleted = 0
        var freed: Int64 = 0
        var failed: [(String, String)] = []
        var protected: [String] = []
        let fm = FileManager.default
        
        // 按删除策略分组
        let trashItems = items.filter { $0.deletionMethod == nil }
        let specialItems = items.filter { $0.deletionMethod != nil }
        
        // ── 常规删除（废纸篓）──
        for item in trashItems {
            progress("正在删除: \(item.name)")
            
            // ⚠️ 安全网：检查路径是否在不可删除名单中
            if neverDeletePaths.contains(item.path) {
                protected.append(item.name)
                continue
            }
            
            // ⚠️ 安全网：检查路径是否以系统前缀开头（二次校验）
            let pathLower = item.path.lowercased()
            if systemPrefixes.contains(where: { pathLower.contains($0) }) {
                protected.append(item.name)
                continue
            }
            
            do {
                let size = item.size
                var trashURL: NSURL?
                try fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: &trashURL)
                deleted += 1
                freed += size
                Thread.sleep(forTimeInterval: 0.05)
            } catch {
                do {
                    let attrs = try fm.attributesOfItem(atPath: item.path)
                    let size = (attrs[.size] as? Int64) ?? 0
                    try fm.removeItem(atPath: item.path)
                    deleted += 1
                    freed += size
                } catch {
                    failed.append((item.name, error.localizedDescription))
                }
            }
        }
        
        // ── 特殊删除策略 ──
        for item in specialItems {
            guard let method = item.deletionMethod else { continue }
            progress("正在清理: \(item.name)")
            
            switch method {
            case .trash:
                break // 不应到这里
                
            case .launchItem(let label, let domain):
                let result = cleanLaunchItem(label: label, domain: domain, plistPath: item.path)
                switch result {
                case .success:
                    deleted += 1
                    freed += item.size
                case .protected:
                    protected.append(item.name)
                case .failure(let msg):
                    failed.append((item.name, msg))
                }
                
            case .extensionPlugin(let pluginPath):
                let result = cleanExtension(pluginPath: pluginPath)
                switch result {
                case .success:
                    deleted += 1
                case .protected:
                    protected.append(item.name)
                case .failure(let msg):
                    failed.append((item.name, msg))
                }
                
            case .btmReset:
                let result = cleanBTMEntry()
                switch result {
                case .success:
                    deleted += 1
                case .protected:
                    protected.append(item.name)
                case .failure(let msg):
                    failed.append((item.name, msg))
                }
                
            case .disabledCache(let plistPath, let entryKey):
                let result = cleanDisabledCache(plistPath: plistPath, entryKey: entryKey)
                switch result {
                case .success:
                    deleted += 1
                case .protected:
                    protected.append(item.name)
                case .failure(let msg):
                    failed.append((item.name, msg))
                }
                
            case .manualOnly(let reason):
                failed.append((item.name, "需手动处理: \(reason)"))
            }
            
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        return (deleted, freed, failed, protected)
    }
    
    // MARK: - 清理启动项
    private static func cleanLaunchItem(label: String, domain: LaunchDomain, plistPath: String) -> CleanResult {
        let fm = FileManager.default
        
        // 安全网：不卸载系统标签
        for prefix in neverUnloadLabels {
            if label.lowercased().hasPrefix(prefix) { return .protected }
        }
        
        // ⚠️ 系统级 daemon 需要 sudo，标记为需手动处理
        if domain == .system {
            // 尝试先删 plist（移到废纸篓可能也需要权限，但文件可能可读）
            guard fm.fileExists(atPath: plistPath) else { return .success }
            
            // 检查是否有写权限
            guard fm.isWritableFile(atPath: plistPath) else {
                return .failure("需管理员权限。请在终端执行: sudo rm \"\(plistPath)\"")
            }
            
            // 尝试 bootout + 删除
            do {
                try Process.run("/bin/launchctl", arguments: ["bootout", "system/\(label)"])
            } catch {
                // bootout 失败可能因为权限或服务未加载，忽略，继续删文件
            }
            
            do {
                var trashURL: NSURL?
                try fm.trashItem(at: URL(fileURLWithPath: plistPath), resultingItemURL: &trashURL)
                return .success
            } catch {
                return .failure("删除失败: \(error.localizedDescription)")
            }
        }
        
        // 用户级启动项：正常处理
        let uid = getuid()
        let domainArg = "gui/\(uid)/\(label)"
        
        do {
            try Process.run("/bin/launchctl", arguments: ["bootout", domainArg])
        } catch {
            // bootout 失败可能因为服务未加载，忽略
        }
        
        // 删除 plist 文件（移到废纸篓）
        guard fm.fileExists(atPath: plistPath) else {
            return .success // 已经不存在了
        }
        
        do {
            var trashURL: NSURL?
            try fm.trashItem(at: URL(fileURLWithPath: plistPath), resultingItemURL: &trashURL)
            return .success
        } catch {
            return .failure("删除 plist 失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 清理扩展
    private static func cleanExtension(pluginPath: String) -> CleanResult {
        do {
            try Process.run("/usr/bin/pluginkit", arguments: ["-r", pluginPath])
            return .success
        } catch {
            return .failure("pluginkit -r 失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 清理登录项（BTM 重置）
    private static func cleanBTMEntry() -> CleanResult {
        // BTM 条目只能通过 resetbtm 批量重置
        // 单个清理由批量操作完成，这里只做标记
        return .success
    }
    
    // MARK: - 清理 disabled 缓存
    private static func cleanDisabledCache(plistPath: String, entryKey: String) -> CleanResult {
        let fm = FileManager.default
        
        // ⚠️ 系统级 disabled.plist 需要管理员权限
        if plistPath.hasPrefix("/var/") || plistPath.hasPrefix("/Library/") {
            guard fm.isWritableFile(atPath: plistPath) else {
                return .failure("需管理员权限。请在终端执行: sudo /usr/libexec/PlistBuddy -c 'Delete :\(entryKey)' \"\(plistPath)\"")
            }
        }
        
        do {
            try Process.run("/usr/libexec/PlistBuddy", arguments: [
                "-c", "Delete :\(entryKey)",
                plistPath
            ])
            return .success
        } catch {
            return .failure("PlistBuddy 删除失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 批量清理 BTM 数据库
    /// 当存在多个 loginItems 类型的孤儿时，执行一次 sfltool resetbtm
    /// 注意：此操作会重置整个 BTM 数据库，macOS 会在下次登录时重新注册仍存在的项目
    static func resetBTMDatabase() -> Bool {
        do {
            try Process.run("/usr/bin/sfltool", arguments: ["resetbtm"])
            return true
        } catch {
            // sfltool resetbtm 通常在无 sudo 情况下也能执行
            // 失败可能是权限问题
            return false
        }
    }
    
    // MARK: - 清理类型
    private enum CleanResult {
        case success
        case protected
        case failure(String)
    }
}

// MARK: - 模拟数据
struct MockData {
    static var items: [OrphanItem] {
        [
            OrphanItem(name: "Jan", path: "~/Library/Application Support/Jan", location: .applicationSupport, size: 2_800_000_000, isDirectory: true),
            OrphanItem(name: "Law Claw", path: "~/Library/Application Support/Law Claw", location: .applicationSupport, size: 1_000_000_000, isDirectory: true),
            OrphanItem(name: "floatboat", path: "~/Library/Caches/floatboat", location: .caches, size: 571_000_000, isDirectory: true),
        ]
    }
}
