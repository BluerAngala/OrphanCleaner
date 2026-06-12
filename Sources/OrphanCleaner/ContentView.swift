import SwiftUI
import AppKit

// MARK: - Design Tokens — 温暖米色系
enum Cln {
    // 底色
    static let bg = Color(red: 0.965, green: 0.957, blue: 0.941)     // #F6F4F0
    static let surface = Color.white
    static let surfaceSub = Color(red: 0.984, green: 0.976, blue: 0.969) // #FBF9F7
    static let border = Color(red: 0.898, green: 0.878, blue: 0.855)    // #E5E0DA
    static let borderLight = Color(red: 0.933, green: 0.918, blue: 0.898) // #EEEAE5
    
    // 文字
    static let text = Color(red: 0.173, green: 0.149, blue: 0.129)    // #2C2621
    static let text2 = Color(red: 0.569, green: 0.522, blue: 0.478)   // #91857A
    static let text3 = Color(red: 0.737, green: 0.698, blue: 0.659)   // #BCB2A8
    
    // 强调色 — 陶土色（独特且有温度）
    static let accent = Color(red: 0.776, green: 0.482, blue: 0.361)  // #C67B5C
    static let accentDim = Color(red: 0.776, green: 0.482, blue: 0.361, opacity: 0.1)
    static let accentLight = Color(red: 0.776, green: 0.482, blue: 0.361, opacity: 0.06)
    
    // 语义色 — 鼠尾草绿 / 暖琥珀
    static let green = Color(red: 0.478, green: 0.620, blue: 0.494)   // #7A9E7E
    static let greenDim = Color(red: 0.478, green: 0.620, blue: 0.494, opacity: 0.1)
    static let amber = Color(red: 0.890, green: 0.592, blue: 0.216)   // #E39737
    static let amberDim = Color(red: 0.890, green: 0.592, blue: 0.216, opacity: 0.1)
    static let red = Color(red: 0.812, green: 0.333, blue: 0.333)     // #CF5555
    
    static let mono = "SF Mono"
    static let sans = "SF Pro"
}

// MARK: - 主视图
struct ContentView: View {
    @EnvironmentObject var vm: CleanerViewModel
    @State private var showCleanConfirm = false
    
    private var isBusy: Bool {
        if case .scanning = vm.scanState { return true }
        if case .cleaning = vm.cleanState { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── 顶栏 ──
            topBar
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            
            // ── 统计仪表盘 ──
            if case .complete = vm.scanState {
                statsDashboard
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            
            Divider().overlay(Cln.border)
            
            // ── 主内容 ──
            mainContent
            
            // ── 底栏 ──
            if !vm.allOrphans.isEmpty {
                bottomBar
            }
        }
        .background(Cln.bg)
        .preferredColorScheme(.light)
        .alert("确认清理", isPresented: $showCleanConfirm) {
            Button("取消", role: .cancel) { }
            Button("移入废纸篓", role: .destructive) { vm.startClean() }
        } message: {
            let c = vm.selectedOrphans.count
            let s = ByteCountFormatter.string(fromByteCount: vm.selectedTotalSize, countStyle: .file)
            Text("将清理 \(c) 项，释放 \(s)。文件会移到废纸篓，可恢复。")
        }
    }
    
    // MARK: - 顶栏
    private var topBar: some View {
        HStack(spacing: 0) {
            // 品牌（仅此一处）
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Cln.accentLight)
                        .frame(width: 32, height: 32)
                    Image(systemName: "trash.slash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Cln.accent)
                }
                Text("残留清理助手")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Cln.text)
            }
            
            Spacer()
            
            // 右侧操作区
            HStack(spacing: 10) {
                // 空目录开关（扫描完成后显示）
                if case .complete = vm.scanState {
                    emptyDirToggle
                }
                scanButton
                if !vm.allOrphans.isEmpty {
                    cleanButton
                }
            }
        }
    }
    
    // ── 子组件：空目录开关 ──
    private var emptyDirToggle: some View {
        HStack(spacing: 5) {
            Text("空目录")
                .font(.system(size: 11))
                .foregroundColor(Cln.text2)
            Toggle(isOn: $vm.showEmptyDirs) { }
                .toggleStyle(.switch)
                .controlSize(.small)
                .scaleEffect(0.85)
                .onChange(of: vm.showEmptyDirs) { _ in
                    vm.startScan()
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Cln.surfaceSub)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Cln.borderLight, lineWidth: 1))
    }
    
    // ── 子组件：扫描按钮 ──
    private var scanButton: some View {
        Button(action: { vm.startScan() }) {
            HStack(spacing: 5) {
                if case .scanning = vm.scanState {
                    ProgressView()
                        .scaleEffect(0.55)
                        .controlSize(.small)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                }
                Text(isBusy ? "扫描中..." : "扫描检测")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Cln.accent.opacity(isBusy ? 0.5 : 1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(isBusy)
    }
    
    // ── 子组件：清理按钮 ──
    private var cleanButton: some View {
        Button(action: { showCleanConfirm = true }) {
            HStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                Text("清理")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(vm.selectedOrphans.isEmpty ? Cln.text3 : Cln.amber)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(vm.selectedOrphans.isEmpty || isBusy)
    }
    
    // MARK: - 统计仪表盘
    private var statsDashboard: some View {
        Group {
            if case .complete(let found, let total) = vm.scanState {
            let catCount = vm.orphans.filter { !$0.value.isEmpty && $0.key != .emptyDirs }.count
            let maxItemSize = vm.allOrphans.map(\.size).max() ?? 0
            let maxItemFormatted = maxItemSize > 0
                ? byteString(maxItemSize)
                : "—"
            let selFormatted = ByteCountFormatter.string(fromByteCount: vm.selectedTotalSize, countStyle: .file)
            let totalFormatted = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            
            HStack(spacing: 0) {
                Spacer()
                
                // 统计项居中排列
                HStack(spacing: 24) {
                    // 总残留
                    statBlock(
                        value: "\(found)",
                        label: "残留项",
                        sub: totalFormatted,
                        color: found > 0 ? Cln.amber : Cln.green
                    )
                    
                    // 分隔
                    Capsule().fill(Cln.borderLight).frame(width: 1, height: 32)
                    
                    // 已选待清理
                    statBlock(
                        value: "\(vm.selectedOrphans.count)",
                        label: "待清理",
                        sub: vm.selectedOrphans.isEmpty ? "—" : selFormatted,
                        color: vm.selectedOrphans.isEmpty ? Cln.text3 : Cln.amber
                    )
                    
                    Capsule().fill(Cln.borderLight).frame(width: 1, height: 32)
                    
                    // 涉及分类数
                    statBlock(
                        value: "\(catCount)",
                        label: "涉及分类",
                        sub: "共 \(ScanLocation.scanLocations.count) 个目录",
                        color: Cln.accent
                    )
                    
                    Capsule().fill(Cln.borderLight).frame(width: 1, height: 32)
                    
                    // 最大单项
                    statBlock(
                        value: maxItemFormatted,
                        label: "最大单项",
                        sub: found > 0 ? "占比 \((maxItemSize > 0 && total > 0) ? String(format: "%.1f%%", Double(maxItemSize) / Double(total) * 100) : "—")" : "—",
                        color: Cln.accent
                    )
                }
                
                Spacer()
            }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Cln.surface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Cln.borderLight, lineWidth: 1))
            }
        }
    }
    
    // ── 统计块（居中用）──
    private func statBlock(value: String, label: String, sub: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Cln.text)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Cln.text2)
            Text(sub)
                .font(.custom(Cln.mono, size: 9))
                .foregroundColor(color)
        }
        .frame(minWidth: 80)
    }
    
    // ── 格式化字节为简洁字符串（用于最大项等场景）──
    private func byteString(_ size: Int64) -> String {
        if size >= 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        } else if size >= 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return "\(size) B"
        }
    }
    
    // MARK: - 主内容
    @ViewBuilder
    private var mainContent: some View {
        switch vm.scanState {
        case .idle:
            emptyState
        case .scanning(let p):
            scanningState(p)
        case .complete(let found, _):
            if found == 0 {
                cleanState
            } else {
                resultsList
            }
        case .error(let m):
            errorState(m)
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Cln.border, lineWidth: 1)
                        .frame(width: 64, height: 64)
                    Circle()
                        .stroke(Cln.accent.opacity(0.2), lineWidth: 1)
                        .frame(width: 48, height: 48)
                    Image(systemName: "trash.slash")
                        .font(.system(size: 20))
                        .foregroundColor(Cln.accent.opacity(0.6))
                }
                
                Text("检测并清理已卸载软件留下的缓存和配置残留")
                    .font(.system(size: 13))
                    .foregroundColor(Cln.text2)
                    .frame(maxWidth: 280)
                    .multilineTextAlignment(.center)
                
                scanButton
                    .controlSize(.large)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 扫描中
    private func scanningState(_ p: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
                .controlSize(.small)
                .tint(Cln.accent)
            Text(p)
                .font(.system(size: 12))
                .foregroundColor(Cln.text2)
                .monospacedDigit()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 系统干净
    private var cleanState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Cln.green.opacity(0.15), lineWidth: 1)
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Cln.green)
            }
            Text("系统很干净")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Cln.text)
            Text("没有发现已卸载软件的残留数据")
                .font(.system(size: 12))
                .foregroundColor(Cln.text2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 错误
    private func errorState(_ m: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 24))
                .foregroundColor(Cln.red)
            Text("扫描出错")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Cln.text)
            Text(m)
                .font(.system(size: 11))
                .foregroundColor(Cln.text2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 结果列表（树形分组）
    private var resultsList: some View {
        VStack(spacing: 0) {
            // 反馈区
            feedbackSection
                .padding(.horizontal, 24)
                .padding(.top, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ScanLocation.allCases) { loc in
                        let items = vm.orphans[loc] ?? []
                        if !items.isEmpty {
                            TreeSection(location: loc, items: items, maxSize: vm.allOrphans.map(\.size).max() ?? 1)
                                .environmentObject(vm)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - 反馈区
    @ViewBuilder
    private var feedbackSection: some View {
        Group {
            if case .cleaning(let p) = vm.cleanState {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6).controlSize(.small)
                    Text(p).font(.system(size: 11)).foregroundColor(Cln.text2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Cln.surfaceSub)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Cln.borderLight, lineWidth: 1))
            }
            
            if case .complete(let d, let f) = vm.cleanState {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(Cln.green)
                    Text("已清理 \(d) 项，释放 \(ByteCountFormatter.string(fromByteCount: f, countStyle: .file))")
                        .font(.system(size: 11)).foregroundColor(Cln.green)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Cln.greenDim)
                .cornerRadius(8)
            }
            
            if case .partial(let d, let failed, let prot) = vm.cleanState {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundColor(Cln.amber)
                        Text("清理完成：\(d) 项成功")
                            .font(.system(size: 11)).foregroundColor(Cln.amber)
                        if !failed.isEmpty { Text("· \(failed.count) 项失败").font(.system(size: 11)).foregroundColor(Cln.red) }
                        if !prot.isEmpty { Text("· \(prot.count) 项受保护跳过").font(.system(size: 11)).foregroundColor(Cln.text2) }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Cln.amberDim)
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 底栏
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Cln.border)
            HStack(spacing: 16) {
                // 左侧：选择状态
                HStack(spacing: 8) {
                    Image(systemName: vm.selectedOrphans.isEmpty ? "circle" : "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(vm.selectedOrphans.isEmpty ? Cln.border : Cln.accent)
                    Text("已选 \(vm.selectedOrphans.count) / \(vm.allOrphans.count) 项")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Cln.text)
                    if !vm.selectedOrphans.isEmpty {
                        Text("· 将释放 \(ByteCountFormatter.string(fromByteCount: vm.selectedTotalSize, countStyle: .file))")
                            .font(.custom(Cln.mono, size: 10))
                            .foregroundColor(Cln.amber)
                    }
                }
                
                Spacer()
                
                // 右侧：操作
                HStack(spacing: 10) {
                    Button("全选") { withAnimation { vm.selectAll() } }
                        .font(.system(size: 11))
                        .foregroundColor(Cln.accent)
                        .buttonStyle(.plain)
                    Button("取消") { withAnimation { vm.deselectAll() } }
                        .font(.system(size: 11))
                        .foregroundColor(Cln.text2)
                        .buttonStyle(.plain)
                    
                    Divider().frame(height: 16).overlay(Cln.border)
                    
                    Button(action: { showCleanConfirm = true }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("清理选中 (\(vm.selectedOrphans.count))")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(vm.selectedOrphans.isEmpty ? Cln.text3 : Cln.amber)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.selectedOrphans.isEmpty || isBusy)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Cln.surface)
        }
    }
}

// MARK: - 树形分组
struct TreeSection: View {
    @EnvironmentObject var vm: CleanerViewModel
    let location: ScanLocation
    let items: [OrphanItem]
    let maxSize: Int64
    @State private var expanded = false
    
    private var allSel: Bool { items.allSatisfy { vm.selectedItems.contains($0.id) } }
    private var secSize: Int64 { items.reduce(0) { $0 + $1.size } }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── 分组标题 ├─
            Button(action: { withAnimation(.spring(duration: 0.3)) { expanded.toggle() } }) {
                HStack(spacing: 10) {
                    // 全选复选框（与子项对齐）
                    Button(action: { vm.toggleAll(for: location) }) {
                        Image(systemName: allSel ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(allSel ? Cln.accent : Cln.border)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help(allSel ? "取消全选" : "全选本组")
                    
                    // 折叠箭头
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(Cln.text3)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .animation(.spring(duration: 0.3), value: expanded)
                    
                    // 位置图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Cln.accentLight)
                            .frame(width: 24, height: 24)
                        Image(systemName: location.icon)
                            .font(.system(size: 10))
                            .foregroundColor(Cln.accent)
                    }
                    
                    // 位置名称
                    Text(location.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Cln.text)
                        .help(location == .emptyDirs
                              ? location.riskDescription
                              : "~/Library/\(location.rawValue) — \(location.riskDescription)")
                    
                    Spacer()
                    
                    // 统计
                    HStack(spacing: 8) {
                        Text("\(items.count) 项")
                            .font(.custom(Cln.mono, size: 10))
                            .foregroundColor(Cln.text3)
                        Text(ByteCountFormatter.string(fromByteCount: secSize, countStyle: .file))
                            .font(.custom(Cln.mono, size: 10))
                            .foregroundColor(Cln.accent)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // ── 子项列表 ──
            if expanded {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        TreeItemRow(item: item, maxSize: maxSize)
                            .environmentObject(vm)
                        if i < items.count - 1 {
                            Divider()
                                .overlay(Cln.borderLight)
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(Cln.surface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Cln.borderLight, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }
}

// MARK: - 树形条目行
struct TreeItemRow: View {
    @EnvironmentObject var vm: CleanerViewModel
    let item: OrphanItem
    let maxSize: Int64
    @State private var hovered = false
    @State private var lastTapTime = Date.distantPast
    
    private var sel: Bool { vm.selectedItems.contains(item.id) }
    private var barRatio: CGFloat {
        guard maxSize > 0 else { return 0 }
        return max(0.04, CGFloat(item.size) / CGFloat(maxSize) * 0.85)
    }
    // 统一单位格式化：>= 1MB 显示 MB，>= 1KB 显示 KB，否则显示 B
    private var formattedSize: String {
        if item.size >= 1_048_576 {
            return String(format: "%.1f MB", Double(item.size) / 1_048_576)
        } else if item.size >= 1024 {
            return String(format: "%.1f KB", Double(item.size) / 1024)
        } else {
            return "\(item.size) B"
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // 左缩进占位
            Color.clear.frame(width: 4)
            
            // 勾选（独立按钮：仅切换选中状态）
            Button(action: { toggle() }) {
                Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(sel ? Cln.accent : Cln.border)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help(sel ? "取消选中" : "选中此项")
            
            // 可点击的内容区（单击复制路径，双击打开文件夹）
            HStack(spacing: 10) {
                // 类型标记
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Cln.bg)
                        .frame(width: 18, height: 18)
                    Image(systemName: item.size == 0 ? "doc.text" : "doc")
                        .font(.system(size: 8))
                        .foregroundColor(Cln.text3)
                }
                
                // 名称（带 tooltip）
                Text(item.name)
                    .font(.system(size: 12))
                    .foregroundColor(Cln.text)
                    .lineLimit(1)
                    .help(item.path)  // 悬停显示完整路径
                
                Spacer()
                
                // 空目录标记
                if item.size == 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 8))
                            .foregroundColor(Cln.text3)
                        Text("空目录")
                            .font(.system(size: 9))
                            .foregroundColor(Cln.text3)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Cln.surfaceSub)
                    .cornerRadius(3)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Cln.borderLight, lineWidth: 1))
                }
                
                // 进度条
                if maxSize > 0 && item.size > 0 {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Cln.bg)
                            .frame(width: 48, height: 4)
                        Capsule()
                            .fill(item.size > Int64(Double(maxSize) * 0.3) ? Cln.amber : Cln.accent)
                            .frame(width: max(4, 48 * barRatio), height: 4)
                            .opacity(0.85)
                    }
                }
                
                // 大小
                Text(item.size == 0 ? "—" : formattedSize)
                    .font(.custom(Cln.mono, size: 11))
                    .foregroundColor(item.size == 0 ? Cln.text3 : Cln.text2)
                    .frame(width: 72, alignment: .trailing)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 14)
        .background(hovered ? Cln.surfaceSub : Color.clear)
        .cornerRadius(6)
        .onHover { hovered = $0 }
    }
    
    /// 处理单击/双击：单击复制路径，双击打开文件夹
    private func handleTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.3 {
            // 双击 → 打开文件夹
            lastTapTime = .distantPast
            openInFinder()
        } else {
            // 单击 → 延迟判断是否变为双击
            lastTapTime = now
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                guard lastTapTime == now else { return }
                copyPathToClipboard()
            }
        }
    }
    
    /// 复制完整路径到剪贴板
    private func copyPathToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.path, forType: .string)
        // 简单的反馈：状态栏闪烁感（通过 hover 颜色闪一下）
        hovered = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            hovered = false
        }
    }
    
    /// 在 Finder 中打开所在文件夹并选中文件
    private func openInFinder() {
        let parent = (item.path as NSString).deletingLastPathComponent
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: parent)
    }
    
    private func toggle() {
        withAnimation(.easeOut(duration: 0.12)) {
            if sel { vm.selectedItems.remove(item.id) }
            else { vm.selectedItems.insert(item.id) }
        }
    }
}

// MARK: - 预览
#Preview {
    ContentView()
        .environmentObject(CleanerViewModel())
        .frame(width: 800, height: 600)
}
