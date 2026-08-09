# Mono for Android

本地有声书播放器的 Android 实现。产品定位见[根目录 README](../README.md)，跨端架构见 [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)。

> **范围提示**：Android 端只实现了核心播放链路，功能明显少于 iOS 端。请先看下方「与 iOS 的差距」，不要假设两端对等。

## 技术选型

| 项 | 值 |
|---|---|
| 语言 | Kotlin 1.9.20 |
| UI | Jetpack Compose（Compose BOM 2023.10.01）+ Material 3 |
| 音频 | Media3 1.2.0（ExoPlayer + MediaSession） |
| 持久化 | SharedPreferences |
| minSdk / target / compileSdk | 26 / 34 / 34 |
| JVM target | 17 |
| AGP / Gradle | 8.2.0 / 8.5（由 wrapper 固定） |

## 构建

需要 **JDK 17** 与 **Android SDK 34**。

```bash
./gradlew assembleDebug
```

请使用仓库自带的 wrapper（它锁定 Gradle 8.5），不要用系统全局的 `gradle`——版本不匹配会因 AGP 8.2.0 的兼容范围而失败。

SDK 位置通过环境变量 `ANDROID_HOME` 指定，或在本目录下新建 `local.properties`：

```properties
sdk.dir=/path/to/Android/sdk
```

该文件包含本机路径，已被 `.gitignore` 排除，不要提交。

release 构建未配置签名，`isMinifyEnabled = false`，没有 product flavor。

## 目录结构

```
app/src/main/
├── AndroidManifest.xml
├── java/com/mono/
│   ├── MonoApplication.kt            # 持有 FileRepository 与 PreferencesManager 的单例宿主
│   ├── MainActivity.kt               # 唯一 Activity：申请权限、拉起服务、承载 Compose
│   │
│   ├── data/
│   │   ├── model/                    # AudioFolder、AudioTrack
│   │   ├── repository/FileRepository.kt      # 目录扫描、时长读取、删除
│   │   └── preferences/PreferencesManager.kt # SharedPreferences 封装
│   │
│   ├── player/
│   │   ├── AudioPlaybackService.kt   # MediaSessionService + ExoPlayer
│   │   └── PlaybackState.kt
│   │
│   └── ui/
│       ├── navigation/NavGraph.kt    # 三个目的地：folder_list / track_list / player
│       ├── screens/                  # FolderListScreen、TrackListScreen、PlayerScreen
│       ├── components/MiniPlayer.kt
│       └── theme/Theme.kt
└── res/
    ├── values/strings.xml
    ├── values/themes.xml
    ├── drawable/app_icon.png
    └── drawable-night/app_icon.png
```

全局依赖没有用 DI 框架，统一挂在 `MonoApplication.instance` 上；播放服务通过 `AudioPlaybackService.getInstance()` 取。

## 权限与音频来源

清单中声明的权限：

| 权限 | 用途 |
|---|---|
| `READ_MEDIA_AUDIO` | Android 13+ 读取音频文件 |
| `READ_EXTERNAL_STORAGE`（`maxSdkVersion=32`） | Android 12 及以下读取音频文件 |
| `POST_NOTIFICATIONS` | Android 13+ 展示播放通知 |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | 后台播放 |
| `WAKE_LOCK` | 息屏播放 |

未申请 `INTERNET`，也未申请 `MANAGE_EXTERNAL_STORAGE`。运行时权限在 `MainActivity.onCreate` 中按系统版本分支申请。

音频读取自公共存储的 **`Music/Mono/`**（`Environment.getExternalStoragePublicDirectory(DIRECTORY_MUSIC)` 下的 `Mono` 子目录），首次访问时自动创建。这里走的是直接的 `java.io.File` 访问，**没有使用 MediaStore，也没有使用 SAF**——因此音频不会出现在系统媒体库里，也不需要用户手动选目录，但代价是依赖存储权限。

导入方式：把整个书籍文件夹用 USB 文件传输或手机文件管理器复制到 `Music/Mono/`。

## 关键行为

**扫描**（`FileRepository`）：只列 `Music/Mono/` 下的第一层目录，且该目录直接包含至少一个受支持音频文件才算一本书；书内**不递归**子目录。受支持扩展名为 `mp3`、`m4a`、`m4b`、`wav`、`aac`、`flac`、`ogg`、`wma`，大小写不敏感。排序使用自定义的 `NaturalOrderComparator`（按数字块比较），保证 `01` 排在 `10` 前。

**时长**由 `MediaMetadataRetriever` 读取，缓存在 `ConcurrentHashMap` 中。列表分两阶段加载：先秒出文件名，再在 IO 线程回填时长。缓存仅存在于内存，进程重启后需要重读。

**播放**（`AudioPlaybackService`）：继承 `MediaSessionService`，`ExoPlayer` 打开了 `handleAudioFocus = true` 与 `setHandleAudioBecomingNoisy(true)`，因此音频焦点抢占与拔耳机暂停由播放器自行处理。通知栏与锁屏控件由 Media3 的默认媒体通知提供，本项目没有自定义通知代码。前进后退为 15 秒；上一章在已播放超过 3 秒时先回到本章开头。一章结束自动接下一章，到最后一章停止，无循环与随机。

**持久化**（`PreferencesManager`）：SharedPreferences 文件 `mono_prefs`，只有三个键——`current_track_path`、`current_position`、`playback_speed`。也就是说进度是**全局单条记录**，不区分书籍，换一本书就会覆盖上一本的进度。

写入时机是暂停（`pause()` 与 ExoPlayer 的 `onIsPlayingChanged(false)`）、服务销毁，以及 `MainActivity.onPause`。**播放过程中没有周期性存档**——进程若在播放中被系统杀掉，进度会回退到上一次暂停或切后台的位置。iOS 端有 30 秒一次的定时存档，这里没有。

**恢复**：`restorePlayback` 只做 prepare + seek，**不会自动开始播放**，需要用户手动点。

**删除**：长按文件夹或章节 → 确认对话框 → 直接 `File.delete()`，无回收站、无撤销。

## 与 iOS 的差距

以下 iOS 已有的功能在 Android 端**完全不存在**，写文档或做需求评估时请勿假定其存在：

| 功能 | Android 现状 |
|---|---|
| 搜索 | 无。没有任何筛选入口 |
| 设置页 | 无。导航图只有三个目的地 |
| 睡眠定时 | 无 |
| 跳过片头 / 片尾 | 无 |
| 逐章 / 逐书进度记忆 | 无，只有一条全局记录 |
| 启动自动播放 | 无 |
| 设计令牌体系 | 无，颜色散落在各 Composable 中 |
| 无障碍打磨 | 无系统性处理，仅依赖 Compose 默认语义 |

**倍速是对齐的**：两端都是 `0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0 / 2.5 / 3.0` 九档。

删除交互也不同：Android 是**长按**，iOS 是滑动。

## 已知问题

欢迎认领，改动前请先开 issue：

- 播放器上前进／后退按钮用的是 `Replay10` / `Forward10` 图标，实际步进却是 15 秒，图标与行为不符。
- `AudioPlaybackService.notifyStateChanged()` 是空实现，没有 Flow / StateFlow；界面靠 200–500ms 轮询读取播放状态，既费电又容易掉帧。
- `MainActivity` 用 `startService` 而非 `startForegroundService` 拉起播放服务。
- `strings.xml` 只被部分使用，许多文案直接硬编码在 Composable 里，两处内容已经开始不一致。
- `themes.xml` 的 `Theme.Mono` 继承自框架的 `android:Theme.Material.Light.NoActionBar`（Material 2），且没有 `values-night/`，所以启动窗口在深色模式下仍是浅色；Compose 层在运行时才把状态栏纠正过来。
- 只有 `drawable/app_icon.png` 与 `drawable-night/app_icon.png`（两者字节完全相同），没有 `mipmap-*` 密度分桶，也没有自适应图标（`ic_launcher` adaptive icon）与主题图标层。
- 未做本地化，文案为硬编码简体中文。
- 不解析 ID3 / 章节元数据，不显示封面。

## 测试

**目前没有任何测试**：`app/src/` 下只有 `main/`，没有 `test/` 或 `androidTest/` 源集。`build.gradle.kts` 里声明的 `testInstrumentationRunner` 是模板残留，没有对应依赖，也没有可运行的用例。

改动播放或文件扫描后请手动回归：导入 → 播放 → 通知栏／锁屏控制 → 切后台 → 重开确认进度恢复。
