# Mono for iOS

本地有声书播放器的 iOS 实现。产品定位与导入方式见[根目录 README](../README.md)，跨端架构见 [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)。这份文档面向要改这份代码的人。

## 技术选型

| 项 | 值 |
|---|---|
| 语言 | Swift 5 |
| UI | UIKit，纯代码布局；storyboard 只用于 LaunchScreen |
| 音频 | `AVPlayer` + `AVPlayerItem`（`AVFoundation`） |
| 锁屏 / 远程控制 | `MPRemoteCommandCenter` + `MPNowPlayingInfoCenter`（`MediaPlayer`） |
| 持久化 | `UserDefaults` + `Caches/` 下的时长缓存 JSON |
| 部署目标 | iOS 18.2 |
| 设备 | iPhone + iPad |
| 依赖 | 无。无 SPM / CocoaPods / Carthage |

## 构建

```bash
xcodebuild -project Mono.xcodeproj -scheme Mono \
  -destination 'generic/platform=iOS Simulator' build
```

真机安装需在 Xcode 中把 Signing 换成你自己的团队。项目使用 Xcode 的文件系统同步分组（`PBXFileSystemSynchronizedRootGroup`），**新增 `.swift` 文件不需要手动加入 target**，放进 `Mono/` 目录即自动参与编译。

## 目录结构

```
Mono/
├── AppDelegate.swift            # 仅做 scene 配置
├── SceneDelegate.swift          # 窗口与导航栈；启动恢复播放；退到后台时存档
├── Info.plist                   # 后台音频、文件共享、scene 清单
│
├── Models/
│   └── AudioTrack.swift         # AudioTrack / AudioFolder
│
├── Services/                    # 三个单例，全局状态都在这里
│   ├── AudioPlayerManager.swift    # 播放、变速、睡眠定时、跳过片头片尾、远程控制
│   ├── FileService.swift           # 目录扫描、时长读取与缓存、删除
│   └── PlaybackStateManager.swift  # UserDefaults 读写
│
├── Presentation/                # 纯逻辑层，不 import UIKit
│   ├── PlaybackPresentation.swift  # 视图状态结构体 + 纯函数 + 时间格式化
│   └── BookPresentationStore.swift # 书籍状态缓存，书库与搜索共用
│
├── Theme/
│   └── DesignTokens.swift       # 颜色 / 字体 / 间距 / 圆角 / 尺寸令牌
│
├── Views/
│   ├── FolderListViewController.swift    # 书库首页（含搜索入口、继续收听区块）
│   ├── TrackListViewController.swift     # 章节列表（含本书跳过设置）
│   ├── PlayerViewController.swift        # 全屏播放器
│   ├── SearchResultsViewController.swift # 搜索结果
│   ├── SettingsViewController.swift      # 设置
│   ├── MiniPlayerView.swift              # 底部迷你播放条
│   ├── EmptyStateView.swift
│   ├── Cells/                   # BookRowCell、TrackChapterCell
│   ├── Components/              # MonoKit（UI 原语）、ResumeBlockView、TrackListHeaderView
│   └── Overlays/                # MonoSheetOverlay（底部弹层基类）、SpeedPickerOverlay、SleepTimerOverlay
│
├── Extensions/                  # TimeInterval+Format、UIColor+Hex、URL+Documents
├── Base.lproj/LaunchScreen.storyboard
└── Assets.xcassets/
```

## 分层约定

**Services 是唯一的可变全局状态**，通过 `.shared` 访问。`AudioPlayerManager` 用弱引用表持有多个 delegate，因此书库、章节列表、迷你播放条和播放器可以同时监听播放状态。

**Presentation 层不碰 UIKit**。`PlaybackPresenter` 是一组纯函数，把「播放器状态 + 持久化状态 + 文件事实」折算成 `BookPresentation` / `NowPlayingPresentation` 这类结构体；ViewController 只负责把结构体渲染出来。所有时间、时长、倍速字符串都必须走 `MonoFormat`，不要在视图里自己拼——它统一处理了「已播时间向下取整、总时长四舍五入」这类容易在两处写出不一致的细节，以及时长尚未读出时显示 `—`、VoiceOver 读作「时长读取中」的情况。

`BookPresentationStore` 缓存每本书的章节与总时长，书库和搜索结果共用它，以保证同一本书在两个列表里显示完全一致。删除或修改书籍后需要调用它的失效方法。

**视觉一律取 `DesignTokens`**，不要写死颜色和数值。每个颜色都是随 `traitCollection` 变化的 `UIColor`，深色模式因此是自动的——直接用 `#FFFFFF` 会破坏这一点。`MonoKit` 提供标签工厂、主按钮、进度条、首字母色块、分隔线、区块标题等原语，新界面优先复用。

## 关键行为

**扫描规则**（`FileService`）：只枚举 Documents 的第一层，目录内至少含一个受支持音频文件才算一本书；书内**不递归**子目录。文件夹与文件均按 `[.numeric, .caseInsensitive, .widthInsensitive]` 比较排序，所以 `01` 排在 `10` 前面。受支持扩展名定义在 `FileService.supportedExtensions`：`mp3`、`m4a`、`m4b`、`wav`、`aac`、`flac`、`caf`。

**时长读取**是异步的（`AVURLAsset.load(.duration)`），结果缓存在内存并落盘到 `Caches/durationCache.json`。因此列表首次出现时时长可能为空，UI 必须能渲染「时长未知」这个中间态。

**进度持久化**（`PlaybackStateManager`）：全部走 `UserDefaults`。除了全局的「当前音频 + 位置 + 倍速」，还有按书维度的 `mono_folder_last_track_<书名>`、`mono_folder_skip_intro/outro_<书名>`，以及按章维度的 `mono_track_position_<相对路径>`。

路径以 **Documents 相对路径**存储，不是绝对路径——iOS 每次安装的沙盒容器 UUID 都会变，存绝对路径会导致重装后进度全丢。历史遗留的绝对路径由 `URL+Documents.swift` 按 `/Documents/` 切分迁移。新增任何涉及文件路径的持久化时，请沿用相对路径。

写入时机：播放中每 30 秒、暂停时、seek 完成后，以及 scene 进入后台或失活时。

**播放器细节**：前进后退为 5 秒（锁屏上的 skip 命令被主动禁用，因此锁屏显示的是上一章／下一章）。跳片头仅在该章没有存档位置、且总时长大于「片头 + 10 秒」时生效；跳片尾在播放中触发并直接进入下一章，每章只触发一次。睡眠定时支持 15/30/45/60/90 分钟、1–1440 分钟自定义与「播完本章」，结束前 30 秒音量渐弱。

**中断与路由**：`AVAudioSession` 用 `.playback` + `.spokenAudio`；来电等中断结束后若系统建议恢复则自动续播，拔出耳机（`.oldDeviceUnavailable`）则暂停。

**搜索**只匹配书名，不匹配章节名——这是有意为之，界面上也明确告知了用户。

## 无障碍

这些是既有基线，改 UI 时请一并维护：

- **动态字体**：字体统一由 `DesignTokens.font(_:weight:)` / `numberFont(_:weight:)` 产生，标签工厂已设 `adjustsFontForContentSizeCategory`。时间与时长必须用等宽数字字体，否则秒数跳动时会抖。
- **超大字号布局**：多处 `registerForTraitChanges([UITraitPreferredContentSizeCategory.self])`，在辅助功能字号下切换为纵向排列（播放器工具行、续听区块的时间行等）。加新控件时请在 AX5 档位下自测。
- **VoiceOver**：列表行合并语义，只暴露一个带完整描述的元素；装饰性视图设 `isAccessibilityElement = false`；进度条自定义了 ±5 秒的增减步进；弹层设 `accessibilityViewIsModal`，关闭后把焦点还给触发它的控件。
- **减弱动效**：动画前查 `DesignTokens.prefersReducedMotion`，开启时用淡入淡出代替位移。
- **不靠颜色单独表意**：选中态同时用色调 + 字重 + 对勾；不可用的上一章／下一章按钮是真的 `isEnabled = false`。
- 点击热区不小于 `DesignTokens.hitTarget`（44pt）。
- 主要控件都带 `accessibilityIdentifier`（如 `player.playPause`、`library.book.row`），命名为 `<页面>.<元素>`，方便后续接 UI 测试。

## 现状与注意事项

- **没有任何测试 target**，工程只有 `Mono` 一个 target。改动播放或持久化后请手动回归：导入 → 播放 → 锁屏控制 → 杀进程 → 重开确认续播。
- 文案全部为硬编码简体中文，无 `.strings` / String Catalog，未做本地化。
- 不解析 ID3 / 章节元数据，不显示封面。首字母色块是刻意的设计选择，不是待补的占位图。
- App 内不发起任何网络请求。设置页的「发送反馈」是一个 `mailto:` 链接，交给邮件 App 处理。
