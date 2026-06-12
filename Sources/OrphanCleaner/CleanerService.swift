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
        
        for item in items {
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
                
                // 尝试先移到废纸篓（可恢复）
                var trashURL: NSURL?
                try fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: &trashURL)
                
                deleted += 1
                freed += size
                Thread.sleep(forTimeInterval: 0.05)
                
            } catch {
                // 移到废纸篓失败 → 尝试直接删除（仍走安全网）
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
        
        return (deleted, freed, failed, protected)
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
