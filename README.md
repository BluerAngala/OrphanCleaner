# 残留清理助手 (OrphanCleaner)

macOS 原生 App，检测并清理已卸载软件留下的缓存和配置残留。

## 功能

- **一键检测**：扫描 `~/Library` 下 6 个目录，与已安装应用交叉比对，找出孤儿残留
- **一键清理**：选定后移至废纸篓（可恢复）
- **安全防护**：五层安全网确保不会误删系统文件或正在使用的应用数据

## 技术栈

| 层 | 技术 |
|---|---|
| UI | SwiftUI (macOS 13+) |
| 构建 | Swift Package Manager |
| 部署 | 直接编译生成 `.app` 包 |

## 项目结构

```
OrphanCleaner/
├── Package.swift                          # SwiftPM 构建配置
├── Sources/
│   └── OrphanCleaner/
│       ├── OrphanCleanerApp.swift         # @main 入口
│       ├── ContentView.swift              # SwiftUI 界面
│       ├── Models.swift                   # 数据模型 + 安全白名单
│       ├── Scanner.swift                  # 扫描引擎（匹配逻辑核心）
│       ├── CleanerService.swift           # 清理引擎（含路径安全网）
│       ├── CleanerViewModel.swift         # 状态管理
│       └── Resources/
│           └── Info.plist                 # App 元信息
└── build.sh                               # 构建脚本
```

## 构建 & 运行

```bash
# 1. 编译
swift build -c release

# 2. 生成 .app 包
./build.sh

# 3. 运行
open Build/残留清理助手.app

# 或复制到 Applications
cp -r Build/残留清理助手.app ~/Applications/
```

> 也可用 Xcode 打开：`open Package.swift`

## 核心逻辑：扫描匹配引擎

扫描的核心在 `Scanner.swift` 中，采用 **6 层匹配策略** 逐项比对：

### 匹配策略（按优先级）

| 策略 | 名称 | 说明 | 示例 |
|------|------|------|------|
| ① | 精确匹配 | 目录名与 bundle ID 或应用名完全一致 | `com.tencent.xinWeChat` → bundle ID 匹配 ✅ |
| ② | Token 匹配 | 目录名是已安装应用名中的一个单词 | `Code` → `Visual Studio Code` 含 `code` ✅ |
| ③ | 组件匹配 | 拆分目录名的 token，逐一比对 | `Google` → `Google Chrome` 的 token `google` ✅ |
| ④ | Bundle ID 前缀/后缀 | 去掉 `.ShipIt` 等后缀后匹配 | `cn.trae.solo.app.ShipIt` → 去掉 `ShipIt` 后匹配 TRAE SOLO ✅ |
| ⑤ | 组件重叠 | 点分命名的连续组件重叠匹配 | `com.trae.solo.app` 与 `cn.trae.solo.app` 共享 `trae.solo.app` ✅ |
| ⑥ | 硬编码别名 | 已知的 app 名 → 目录名映射 | `cherrystudiopi` → `cherry studio` ✅ |

### 不匹配 = 标记为残留

经过 6 层匹配仍无法对应任何已安装应用的，视为孤儿残留。

## 安全体系：五层防护

```
用户操作触发删除
    ↓
① 扫描过滤器 ──── 扫描时自动跳过系统/Apple 目录
    ↓
② 路径安全网 ──── 硬编码不可删除路径（iPhone备份、通讯录等）
    ↓
③ 二次确认弹窗 ── 用户确认后才执行
    ↓
④ 移到废纸篓 ──── 不走 rm，可恢复
    ↓
⑤ 手动勾选 ────── 每项可单独取消
```

### 系统目录白名单

在 `Models.swift` 中定义了：
- `systemPrefixes`：以 `com.apple.`、`apple` 开头的目录
- `systemDirNames`：约 200 个已知系统目录名
- `alwaysKeep`：用户自己的工具（`baoyu-skills`、`lark-cli`、`pi-web-tauri` 等）
- `neverDeletePaths`：全路径级别的最终安全网

## 扫描范围

扫描 `~/Library` 下的 6 个目录：

| 目录 | 说明 | 删除影响 |
|------|------|----------|
| `Application Support` | 应用数据 | 可能导致设置丢失 |
| `Caches` | 缓存文件 | 下次使用会重新生成 |
| `Logs` | 日志 | 不影响运行 |
| `Preferences` | 偏好设置 (.plist) | 恢复默认设置 |
| `WebKit` | 网页渲染缓存 | 重新加载 |
| `Saved Application State` | 窗口状态 | 不影响使用 |

## 扩展指南

### 添加新的系统目录到白名单

在 `Models.swift` 的 `systemDirNames` 中添加：

```swift
let systemDirNames: Set<String> = [
    // ... 现有条目 ...
    "you-new-system-dir",
]
```

### 添加硬编码别名

在 `Scanner.swift` 的 `manualMapping` 中添加：

```swift
let manualMapping: [String: Set<String>] = [
    // ... 现有映射 ...
    "dirname": ["installed app name"],
]
```

### 添加不可删除路径

在 `Models.swift` 的 `neverDeletePaths` 闭包中添加：

```swift
"\(home)/Library/Application Support/YourImportantPath",
```

## License

MIT
