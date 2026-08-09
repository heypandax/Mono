# 贡献指南

Mono 是一个小型双平台项目，没有专职维护团队。欢迎 issue 和 PR，但请先读完这一页，它能省掉来回沟通的时间。

## 开始之前

先开一个 issue 说明你想做什么，尤其是新功能。Mono 的产品边界是刻意收窄的（见 [README](README.md) 与 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)），有些提议会因为超出边界而被婉拒——提前聊一句，好过写完代码才发现方向不对。

小修小补（错别字、崩溃修复、明显的逻辑错误）可以直接提 PR。

## 环境要求

| 平台 | 要求 |
|------|------|
| iOS | macOS + Xcode 16.2 或更高；部署目标 iOS 18.2 |
| Android | JDK 17 + Android SDK 34；Gradle 由 wrapper 提供（8.5） |

两个平台互相独立，只改其中一个时不需要装另一个的工具链。

## 提交前的构建检查

改动 iOS 代码：

```bash
xcodebuild -project MonoiOS/Mono.xcodeproj -scheme Mono \
  -destination 'generic/platform=iOS Simulator' build
```

改动 Android 代码：

```bash
cd MonoAndroid && ./gradlew assembleDebug
```

目前项目**没有自动化测试**（两端都没有测试 target 或测试源集），所以构建通过只是底线。涉及播放、文件扫描、进度恢复的改动，请在真机或模拟器上手动走一遍：导入 → 播放 → 后台/锁屏控制 → 杀掉进程 → 重开确认进度恢复，并在 PR 里说明你实际验证了哪些路径。

## 代码风格

仓库根目录有 [`.editorconfig`](.editorconfig)，请让编辑器读取它。要点：

- UTF-8、LF、文件末尾留空行；
- Swift / Kotlin / Gradle KTS 用 4 空格；JSON / YAML 用 2 空格；
- 不要重排、不要格式化与你改动无关的代码，那会淹没 review 的重点。

**iOS**：纯代码 UIKit（仅 LaunchScreen 用 storyboard），用 `// MARK: -` 分段，全局服务走 `static let shared` 单例，颜色/间距/字号一律取 `DesignTokens`，不要写死字面量。

**Android**：Kotlin + Compose，Material 3，异步用协程。

新增 UI 时请一并验证深色模式与字体缩放；iOS 端必须保持现有的动态字体和辅助功能超大字号基线。

## 分支与提交

从 `main` 切分支，命名随意但要能看懂（`fix/sleep-timer-drift`、`feat/android-search`）。

提交信息用祈使句写清楚**做了什么**，一行标题够用，复杂改动在正文补充原因：

```
Fix sleep timer firing early after app resumes

计时基于 wall-clock 而非 CPU 时间，后台挂起期间会漏算。
```

不要把无关改动塞进同一个提交；不要提交 `build/`、`local.properties`、`.env`、Xcode 用户态文件——`.gitignore` 已经覆盖，但请在 `git add` 前扫一眼 `git status`。

## Issue 与 PR

提 issue 请附：平台与系统版本、设备型号、复现步骤、实际与预期表现。播放类问题请说明音频格式和文件夹结构。

提 PR 请附：改了什么、为什么、怎么验证的。改动 UI 请贴截图（浅色 + 深色）。保持 PR 小而聚焦——一个 PR 解决一件事。

## 隐私红线

Mono 是纯本地应用：不联网、不采集、无账号。请不要引入网络请求、埋点 SDK、崩溃上报或任何形式的远程配置。

**不要提交任何音频文件**——包括用来测试的样例。仓库里不放版权内容，也不放你自己的书。测试请用你本机的文件，通过正常导入流程放进设备。截图请避免露出真实的个人书库信息。

## 许可

提交贡献即表示同意你的代码以 [MIT License](LICENSE) 发布。
