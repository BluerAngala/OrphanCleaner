# 残留清理助手 (OrphanCleaner)

macOS 原生 App，检测并清理已卸载软件留下的缓存和配置残留。

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-blue) ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-orange)

## 功能

### 文件残留扫描（6 个目录）
- **一键检测** — 扫描 `~/Library` 下 6 个目录，与已安装应用交叉比对，找出孤儿残留
- **一键清理** — 选定后移至废纸篓（可恢复）

### 启动项残留扫描（3 个位置）🆕
- **用户 LaunchAgents** — `~/Library/LaunchAgents/*.plist`，检测指向已卸载应用的启动项
- **系统 LaunchAgents** — `/Library/LaunchAgents/*.plist`，全局登录启动项
- **系统 LaunchDaemons** — `/Library/LaunchDaemons/*.plist`，系统级守护进程

### 注册表残留扫描（3 类）🆕
- **登录项残留** — 解析 `sfltool dumpbtm`，检测后台任务管理数据库中的幽灵条目
- **Finder 扩展残留** — 解析 `pluginkit`，检测已卸载应用的 Finder 同步扩展
- **服务缓存残留** — 解析 `disabled.plist`，检测 launchctl 状态缓存中的失效条目

### 通用能力
- **智能分组** — 按目录/类型分类展示，默认折叠，展开后按大小排序
- **空目录检测** — 可选扫描已卸载应用留下的空文件夹，独立分组展示
- **快速核查** — 单击条目复制路径，双击在 Finder 中打开文件夹
- **安全防护** — 五层安全网，确保不误删系统文件或正在使用的应用数据

## 截图 / 界面

温暖米色系 UI，树形分组布局：

```
┌──────────────────────────────────────────────────┐
│ 🗑 残留清理助手        [空目录] [扫描检测] [清理]   │  ← 顶栏
├──────────────────────────────────────────────────┤
│          55              8             3          │
│        残留项           待清理        涉及分类     │  ← 居中统计仪表盘
│   789.8 MB 可释放    512.3 MB      共 6 个目录    │
├──────────────────────────────────────────────────┤
│                                                  │
│ ▶ 应用支持 (11项, 182.0 MB)                       │  ← 默认折叠
│ ▶ 缓存 (18项, 607.3 MB)                          │
│ ▼ 空目录 (3项)                                   │  ← 独立分组
│    ☑ 📁 SomeEmptyFolder       📁 空目录    —     │
│    ☑ 📁 AnotherEmpty          📁 空目录    —     │
│                                                  │
├──────────────────────────────────────────────────┤
│ ☑ 已选 8 / 55 项 · 将释放 512.3 MB               │  ← 底栏
│          [全选] [取消] [清理选中]                  │
└──────────────────────────────────────────────────┘
```

### 设计语言

| 属性 | 取值 |
|------|------|
| 底色 | `#F6F4F0` 暖米白 |
| 卡片 | `#FFFFFF` 纯白 + 极淡阴影 |
| 强调色 | `#C67B5C` 陶土色 |
| 成功 | `#7A9E7E` 鼠尾草绿 |
| 警告 | `#E39737` 暖琥珀 |
| 圆角 | 10px |
| 字体 | SF Mono（数据）+ SF Pro（标签） |

### UX 特性

- **树形分组布局** — 按目录分类组织，缩进展示层级关系
- **默认折叠** — 分组标题默认折叠，点击展开/收缩，减少信息过载
- **居中统计仪表盘** — 残留项 / 待清理 / 涉及分类 / 最大单项，四个数据块居中排列
- **中文分类名** — 应用支持、缓存、日志、偏好设置、网页缓存、窗口状态
- **空目录独立分组** — 开启「空目录」开关后，所有空目录单独汇总为一个分组
- **单击复制路径** — 单击条目自动复制完整路径到剪贴板（行闪烁作为反馈）
- **双击打开 Finder** — 双击条目直接在 Finder 中定位文件/目录
- **悬停高亮 + Tooltip** — 悬停显示完整路径 tooltip，行底色变化
- **底栏操作区** — 固定底部显示已选数量/大小 + 全选/取消/清理按钮
- **大/小文件颜色区分** — 进度条随文件大小变色（琥珀色 = 大文件）
- **统一单位格式化** — ≥1MB 显示 MB，≥1KB 显示 KB，<1KB 显示 B，右对齐
- **二次确认弹窗** — 清理前确认，所有文件移入废纸篓（可恢复）

## 技术栈

| 层 | 技术 |
|---|---|
| UI | SwiftUI (macOS 13+) |
| 构建 | Swift Package Manager |
| 部署 | 编译生成 `.app` 包 |

## 项目结构

```
OrphanCleaner/
├── Package.swift                          # SwiftPM 构建
├── Sources/
│   └── OrphanCleaner/
│       ├── OrphanCleanerApp.swift         # @main 入口
│       ├── ContentView.swift              # 全部 UI（树形分组 + 仪表盘 + 交互）
│       ├── Models.swift                   # 数据模型 + 删除策略 + 安全白名单
│       ├── Scanner.swift                  # 扫描引擎（9 类扫描器）
│       │   ├── InstalledAppCollector      #   已安装应用收集（6 层匹配）
│       │   ├── OrphanScanner              #   文件残留扫描（~/Library 6 目录）
│       │   ├── LaunchItemScanner          #   🆕 启动项扫描（LaunchAgents/Daemons）
│       │   ├── BTMScanner                 #   🆕 登录项扫描（sfltool dumpbtm）
│       │   ├── ExtensionScanner           #   🆕 扩展扫描（pluginkit）
│       │   └── DisabledCacheScanner       #   🆕 服务缓存扫描（disabled.plist）
│       ├── CleanerService.swift           # 清理引擎（6 种删除策略）
│       ├── CleanerViewModel.swift         # 状态管理
│       └── Resources/
│           └── Info.plist                 # App 元信息
├── build.sh                               # 构建脚本
└── README.md                              # 本文档
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
| ④ | Bundle ID 前后缀 | 去掉 `.ShipIt` 等后缀后匹配前缀 | `cn.trae.solo.app.ShipIt` → 去掉后缀 → TRAE SOLO ✅ |
| ⑤ | 组件重叠 | 点分命名的连续组件重叠 | `com.trae.solo.app` ↔ `cn.trae.solo.app` 共享 `trae.solo` ✅ |
| ⑥ | 硬编码别名 | 已知目录名 → 应用名映射 | `cherrystudiopi` → `cherry studio` ✅ |

不匹配任何策略 → 标记为孤儿残留。

### 空目录检测

默认关闭。开启后扫描器会把各目录下发现的空目录统一归入「空目录」分组展示，不散落在各分类中。

## 安全体系：五层防护

```
用户触发删除
    ↓
① 扫描过滤器 ──── 自动跳过系统/Apple 目录（com.apple.*、Apple*）
    ↓
② 路径安全网 ──── 硬编码不可删除路径（iPhone备份、通讯录等）
    ↓
③ 二次确认弹窗 ── 用户确认后才执行
    ↓
④ 移到废纸篓 ──── 不走 rm -rf，可恢复
    ↓
⑤ 手动勾选 ────── 每项可单独取消
```

### 系统目录白名单

在 `Models.swift` 中：

- `systemPrefixes` — 以 `com.apple.`、`apple` 开头的目录自动跳过
- `systemDirNames` — ~200 个已知系统目录名（含 `familycircle`、`familycircled` 等）
- `alwaysKeep` — 用户自己的工具（`baoyu-skills`、`lark-cli`、`pi-web-tauri`）
- `neverDeletePaths` — 全路径级别的最终安全网

## 扫描范围

### 文件残留（~/Library）

| 目录 | 中文名 | 说明 | 删除影响 |
|------|--------|------|----------|
| `Application Support` | 应用支持 | 应用数据 | 可能导致设置丢失 |
| `Caches` | 缓存 | 缓存文件 | 下次使用会重新生成 |
| `Logs` | 日志 | 日志 | 不影响运行 |
| `Preferences` | 偏好设置 | 偏好设置 (.plist) | 恢复默认设置 |
| `WebKit` | 网页缓存 | 网页渲染缓存 | 重新加载 |
| `Saved Application State` | 窗口状态 | 窗口状态 | 不影响使用 |

### 启动项残留 🆕

| 位置 | 中文名 | 说明 | 清理方式 |
|------|--------|------|----------|
| `~/Library/LaunchAgents` | 用户启动项 | 用户登录时启动的服务 plist | `launchctl bootout` + 删除 plist |
| `/Library/LaunchAgents` | 系统启动项 | 全局登录启动项 | 同上（需 sudo） |
| `/Library/LaunchDaemons` | 系统守护进程 | 开机即启动的系统服务 | 同上（需 sudo） |

### 注册表残留 🆕

| 类型 | 数据来源 | 说明 | 清理方式 |
|------|----------|------|----------|
| 登录项残留 | `sfltool dumpbtm` | 后台任务管理数据库中的幽灵条目 | `sfltool resetbtm` |
| 扩展残留 | `pluginkit -m -v` | Finder 同步扩展注册残余 | `pluginkit -r <path>` |
| 服务缓存 | `disabled.plist` | launchctl 禁用状态缓存 | `PlistBuddy Delete` |

## 清理方法论

基于实战总结的 macOS 残留清理分层模型：

```
┌─────────────────────────────────────────┐
│ 第 3 层: 注册表残留                      │
│ sfltool BTM / pluginkit / disabled.plist │
│ → 不会自动清理，必须手动干预              │
├─────────────────────────────────────────┤
│ 第 2 层: 启动项残留                      │
│ LaunchAgents / LaunchDaemons plist       │
│ → 即使删了 app，plist 仍然存在            │
├─────────────────────────────────────────┤
│ 第 1 层: 文件残留                        │
│ Application Support / Caches / Logs ...  │
│ → 最明显但也最容易清理                    │
└─────────────────────────────────────────┘
```

### 典型清理链路

以 ToDesk/Docker/Clash 为例的完整清理流程：

1. **文件残留** — 扫描 `~/Library` 下 6 个目录
2. **启动项 plist** — 检查 `LaunchAgents/LaunchDaemons` 中的 plist
3. **launchctl 状态** — `launchctl print-disabled` 查看残留状态缓存
4. **BTM 数据库** — `sfltool dumpbtm` 查看后台任务管理条目
5. **扩展残留** — `pluginkit -m -v` 查看注册的 Finder 扩展
6. **disabled.plist** — 编辑 `/var/db/com.apple.xpc.launchd/disabled.plist`

## 交互说明

| 操作 | 行为 |
|------|------|
| 点击 **复选框** (○/☑) | 切换选中/取消 |
| **单击** 条目文字/大小区域 | 📋 复制完整路径到剪贴板 |
| **双击** 条目文字/大小区域 | 📂 在 Finder 中打开并选中文件 |
| 点击 **分组标题** | 展开/折叠分组 |
| 点击 **分组复选框** | 全选/取消本组 |
| 悬停 **条目** | 显示完整路径 tooltip |
| 开启 **空目录** 开关 | 重新扫描，空目录归入独立分组 |

## 扩展指南

### 添加系统目录到白名单

```swift
// Models.swift → systemDirNames
"your-new-system-dir",
```

### 添加硬编码别名

```swift
// Scanner.swift → manualMapping
"dirname": ["installed app name"],
```

### 添加不可删除路径

```swift
// Models.swift → neverDeletePaths
"\(home)/Library/Application Support/YourImportantPath",
```

## License

MIT
