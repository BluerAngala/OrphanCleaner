import SwiftUI

// MARK: - 主内容视图
struct ContentView: View {
    @EnvironmentObject var vm: CleanerViewModel
    @State private var showDeleteConfirm = false
    
    private var isScanning: Bool {
        if case .scanning = vm.scanState { return true }
        return false
    }
    
    private var isCleaning: Bool {
        if case .cleaning = vm.cleanState { return true }
        return false
    }
    
    var body: some View {
        HSplitView {
            // 左侧面板：统计 + 操作
            leftPanel
                .frame(minWidth: 260, idealWidth: 300)
            
            // 右侧面板：扫描结果
            rightPanel
                .frame(minWidth: 420)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("确认清理", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("确认清理", role: .destructive) { vm.startClean() }
        } message: {
            let count = vm.selectedOrphans.count
            let size = ByteCountFormatter.string(fromByteCount: vm.selectedTotalSize, countStyle: .file)
            Text("将清理 \(count) 项，释放 \(size)\n\n操作会移到废纸篓，需要时可恢复。继续吗？")
        }
    }
    
    // MARK: - 左侧面板
    private var leftPanel: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            Divider()
            
            actionSection
                .padding(20)
            
            Divider()
            
            statsSection
                .padding(20)
            
            Spacer()
            
            statusBar
                .padding(12)
                .background(Color(nsColor: .underPageBackgroundColor))
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - 右侧面板
    private var rightPanel: some View {
        Group {
            switch vm.scanState {
            case .idle:
                welcomeView
            case .scanning(let progress):
                scanningView(progress: progress)
            case .complete(let found, _):
                if found == 0 {
                    emptyView
                } else {
                    resultsView
                }
            case .error(let msg):
                errorView(msg: msg)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 子视图
extension ContentView {
    
    // MARK: 标题
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "trash.slash")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("残留清理助手")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("检测并清理已卸载软件残留")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: 操作区
    private var actionSection: some View {
        VStack(spacing: 12) {
            Button(action: { vm.startScan() }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("一键检测")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .disabled(isScanning)
            
            if !vm.allOrphans.isEmpty {
                Button(action: { showDeleteConfirm = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("一键清理选中")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(vm.selectedOrphans.isEmpty || isCleaning)
                
                HStack(spacing: 16) {
                    Button("全选") { withAnimation(.easeOut(duration: 0.15)) { vm.selectAll() } }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Button("取消全选") { withAnimation(.easeOut(duration: 0.15)) { vm.deselectAll() } }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 清理反馈
            if case .cleaning(let progress) = vm.cleanState {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .controlSize(.small)
                    Text(progress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8)
            }
            
            if case .complete(let deleted, let freed) = vm.cleanState {
                Label("已清理 \(deleted) 项，释放 \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))",
                      systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
            }
            
            if case .partial(let deleted, let failed, let protected) = vm.cleanState {
                VStack(alignment: .leading, spacing: 4) {
                    Label("已清理 \(deleted) 项，\(failed.count) 项失败\(protected.isEmpty ? "" : "，\(protected.count) 项受保护已跳过")",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    ForEach(failed, id: \.0) { name, reason in
                        Text("\(name): \(reason)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.leading, 16)
                    }
                    if !protected.isEmpty {
                        Text("受保护路径（已自动跳过）：")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                        ForEach(protected, id: \.self) { name in
                            Text("🛡 \(name)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: 统计区
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("统计", systemImage: "chart.pie")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if case .complete(let found, let total) = vm.scanState {
                StatCard(label: "发现残留", value: "\(found) 项",
                        icon: "exclamationmark.triangle", color: .orange)
                StatCard(label: "可释放空间", value: ByteCountFormatter.string(fromByteCount: total, countStyle: .file),
                        icon: "externaldrive", color: .blue)
                
                Toggle(isOn: $vm.showEmptyDirs) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                        Text("包含空目录")
                            .font(.caption)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: vm.showEmptyDirs) { _ in vm.startScan() }
                
                if !vm.selectedOrphans.isEmpty {
                    Divider()
                    StatCard(label: "已选择清理", value: "\(vm.selectedOrphans.count) 项",
                            icon: "checkmark.circle", color: .green)
                    StatCard(label: "将释放", value: ByteCountFormatter.string(fromByteCount: vm.selectedTotalSize, countStyle: .file),
                            icon: "arrow.down", color: .green)
                }
            } else {
                Text("点击「一键检测」开始扫描")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: 底部状态栏
    private var statusBar: some View {
        HStack(spacing: 6) {
            switch vm.scanState {
            case .idle:
                Circle().fill(.secondary).frame(width: 6, height: 6)
                Text("就绪")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .scanning(let progress):
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text(progress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            case .complete(let found, _):
                Circle().fill(found == 0 ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(found == 0 ? "系统干净" : "发现 \(found) 项残留")
                    .font(.caption)
                    .foregroundColor(found == 0 ? .green : .orange)
            case .error(let msg):
                Circle().fill(.red).frame(width: 6, height: 6)
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: 欢迎页
    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "trash.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor.opacity(0.5))
                
                VStack(spacing: 6) {
                    Text("欢迎使用残留清理助手")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("比对已安装应用，找出已卸载软件的缓存残留")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ScanLocation.allCases) { loc in
                        HStack(spacing: 10) {
                            Image(systemName: loc.icon)
                                .foregroundColor(.accentColor)
                                .font(.body)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(loc.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("~/Library/\(loc.rawValue)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)
            }
            .padding(32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: 扫描中
    private func scanningView(progress: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .controlSize(.large)
            Text(progress)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: 无残留
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("系统很干净，没有发现残留！")
                .font(.title3)
                .fontWeight(.medium)
            Text("所有已安装应用的缓存数据都正常")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: 错误
    private func errorView(msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
            Text("扫描出错")
                .font(.title3)
            Text(msg)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    // MARK: 结果列表（含可折叠分区）
    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 结果标题栏
                HStack {
                    Label("扫描结果", systemImage: "list.bullet.rectangle")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(vm.allOrphans.count) 项残留 · \(ByteCountFormatter.string(fromByteCount: vm.totalSize, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                // 各分区
                ForEach(ScanLocation.allCases) { location in
                    let items = vm.orphans[location] ?? []
                    if !items.isEmpty {
                        LocationCard(location: location, items: items)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - 可折叠分区卡片
struct LocationCard: View {
    @EnvironmentObject var vm: CleanerViewModel
    let location: ScanLocation
    let items: [OrphanItem]
    @State private var isExpanded: Bool = true
    
    private var allSelected: Bool {
        items.allSatisfy { vm.selectedItems.contains($0.id) }
    }
    
    private var sectionSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 分区标题行（可点击折叠/展开）
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 10) {
                    // 折叠箭头
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    // 全选勾
                    Button(action: { vm.toggleAll(for: location) }) {
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(allSelected ? .accentColor : .secondary)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("全选/取消全选此分区")
                    
                    // 图标 + 名称
                    Image(systemName: location.icon)
                        .foregroundColor(.accentColor)
                        .font(.body)
                    Text(location.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 统计
                    HStack(spacing: 12) {
                        Text("\(items.count) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        Text(ByteCountFormatter.string(fromByteCount: sectionSize, countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 折叠内容
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        OrphanRow(item: item)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 3)
                        
                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - 条目行（带大小进度条）
struct OrphanRow: View {
    @EnvironmentObject var vm: CleanerViewModel
    let item: OrphanItem
    
    @State private var isHovered = false
    
    private var isSelected: Bool {
        vm.selectedItems.contains(item.id)
    }
    
    var body: some View {
        Button(action: { toggle() }) {
            HStack(spacing: 10) {
                // 勾选框
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.6))
                    .font(.body)
                
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(width: 22, height: 22)
                    Image(systemName: item.categoryIcon)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 名称
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if item.size == 0 {
                        Text("空")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(3)
                    }
                }
                
                Spacer()
                
                // 大小（用进度条指示相对大小）
                HStack(spacing: 6) {
                    if vm.scanState != .idle {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .frame(width: 60, height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity(0.5))
                                    .frame(width: relativeWidth(totalWidth: 60), height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                    
                    Text(item.sizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(width: 72, alignment: .trailing)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(isHovered ? Color(nsColor: .selectedControlTextColor).opacity(0.05) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private func relativeWidth(totalWidth: CGFloat) -> CGFloat {
        let maxSize = vm.allOrphans.map(\.size).max() ?? 1
        guard maxSize > 0 else { return 0 }
        return CGFloat(item.size) / CGFloat(maxSize) * totalWidth
    }
    
    private func toggle() {
        withAnimation(.easeOut(duration: 0.12)) {
            if isSelected {
                vm.selectedItems.remove(item.id)
            } else {
                vm.selectedItems.insert(item.id)
            }
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            Spacer()
        }
    }
}

// MARK: - 预览
#Preview {
    ContentView()
        .environmentObject(CleanerViewModel())
        .frame(width: 800, height: 600)
}
