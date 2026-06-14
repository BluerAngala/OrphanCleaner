import Foundation
import Combine

// MARK: - ViewModel
class CleanerViewModel: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var cleanState: CleanState = .idle
    @Published var orphans: [ScanLocation: [OrphanItem]] = [:]
    @Published var selectedItems: Set<UUID> = []
    @Published var expandedLocations: Set<ScanLocation> = Set(ScanLocation.allCases)
    @Published var showEmptyDirs: Bool = true
    
    private var installedIndex: InstalledAppIndex = InstalledAppIndex()
    
    // 所有孤儿条目（扁平化）
    var allOrphans: [OrphanItem] {
        orphans.values.flatMap { $0 }
    }
    
    // 选中的条目
    var selectedOrphans: [OrphanItem] {
        allOrphans.filter { selectedItems.contains($0.id) }
    }
    
    // 选中总大小
    var selectedTotalSize: Int64 {
        selectedOrphans.reduce(0) { $0 + $1.size }
    }
    
    // 总大小（所有发现的）
    var totalSize: Int64 {
        allOrphans.reduce(0) { $0 + $1.size }
    }
    
    // 按位置分组的大小
    func sizeForLocation(_ loc: ScanLocation) -> Int64 {
        (orphans[loc] ?? []).reduce(0) { $0 + $1.size }
    }
    
    // MARK: - 扫描
    func startScan() {
        scanState = .scanning(progress: "正在收集已安装应用列表...")
        cleanState = .idle
        orphans = [:]
        selectedItems = []
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 收集已安装应用
            DispatchQueue.main.async {
                self.scanState = .scanning(progress: "正在扫描系统应用...")
            }
            let installed = InstalledAppCollector.collect()
            self.installedIndex = installed
            
            // 扫描残留（各位置依次报告进度）
            let results = OrphanScanner.scan(installed: installed, includeEmptyDirs: self.showEmptyDirs) { [weak self] msg in
                DispatchQueue.main.async {
                    self?.scanState = .scanning(progress: msg)
                }
            }
            
            DispatchQueue.main.async {
                self.orphans = results
                let count = results.values.flatMap { $0 }.count
                let totalSize = results.values.flatMap { $0 }.reduce(0) { $0 + $1.size }
                
                // 默认全选
                for item in results.values.flatMap({ $0 }) {
                    self.selectedItems.insert(item.id)
                }
                
                self.scanState = .complete(found: count, totalSize: totalSize)
            }
        }
    }
    
    // MARK: - 清理
    func startClean() {
        let items = selectedOrphans
        guard !items.isEmpty else { return }
        
        cleanState = .cleaning(progress: "准备清理...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let result = CleanerService.clean(items) { msg in
                DispatchQueue.main.async {
                    self.cleanState = .cleaning(progress: msg)
                }
            }
            
            // 如果有登录项残留被清理，执行一次 BTM 重置
            let hasBTMItems = items.contains { $0.location == .loginItems }
            if hasBTMItems {
                DispatchQueue.main.async {
                    self.cleanState = .cleaning(progress: "正在重置登录项数据库...")
                }
                let btmOK = CleanerService.resetBTMDatabase()
                if !btmOK {
                    // BTM 重置可能被用户取消授权
                }
            }
            
            DispatchQueue.main.async {
                // 从状态中移除已成功清理的条目（不重新扫描）
                let cleanedIDs = Set(
                    items.enumerated()
                        .filter { i, _ in
                            // 成功的条目：索引不超过 result.deleted，且不在 failed 和 protected 中
                            let failedNames = Set(result.failed.map { $0.0 })
                            let protectedNames = Set(result.protected)
                            return !failedNames.contains(items[i].name)
                                && !protectedNames.contains(items[i].name)
                        }
                        .map { $0.1.id }
                )
                
                for loc in self.orphans.keys {
                    self.orphans[loc]?.removeAll { cleanedIDs.contains($0.id) }
                    // 移除空分组
                    if self.orphans[loc]?.isEmpty == true {
                        self.orphans.removeValue(forKey: loc)
                    }
                }
                
                // 清理选中状态
                self.selectedItems.subtract(cleanedIDs)
                
                if result.failed.isEmpty && result.protected.isEmpty {
                    self.cleanState = .complete(
                        deleted: result.deleted,
                        freedSize: result.freed
                    )
                } else {
                    self.cleanState = .partial(
                        deleted: result.deleted,
                        failed: result.failed,
                        protected: result.protected
                    )
                }
            }
        }
    }
    
    // MARK: - 切换选择
    func toggleAll(for location: ScanLocation) {
        let locationItems = orphans[location] ?? []
        let allSelected = locationItems.allSatisfy { selectedItems.contains($0.id) }
        
        if allSelected {
            for item in locationItems {
                selectedItems.remove(item.id)
            }
        } else {
            for item in locationItems {
                selectedItems.insert(item.id)
            }
        }
    }
    
    func selectAll() {
        for item in allOrphans {
            selectedItems.insert(item.id)
        }
    }
    
    func deselectAll() {
        selectedItems.removeAll()
    }
}
